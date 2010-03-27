#define C_KINO_SORTCOLLECTOR
#define C_KINO_MATCHDOC
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/Collector/SortCollector.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/SortCache.h"
#include "KinoSearch/Index/SortCache/NumericSortCache.h"
#include "KinoSearch/Index/SortCache/TextSortCache.h"
#include "KinoSearch/Index/SortReader.h"
#include "KinoSearch/Plan/FieldType.h"
#include "KinoSearch/Plan/Schema.h"
#include "KinoSearch/Search/HitQueue.h"
#include "KinoSearch/Search/MatchDoc.h"
#include "KinoSearch/Search/Matcher.h"
#include "KinoSearch/Search/SortRule.h"
#include "KinoSearch/Search/SortSpec.h"

#define COMPARE_BY_SCORE      1
#define COMPARE_BY_SCORE_REV  2
#define COMPARE_BY_DOC_ID     3
#define COMPARE_BY_DOC_ID_REV 4
#define COMPARE_BY_ORD1       5
#define COMPARE_BY_ORD1_REV   6
#define COMPARE_BY_ORD2       7
#define COMPARE_BY_ORD2_REV   8
#define COMPARE_BY_ORD4       9
#define COMPARE_BY_ORD4_REV   10
#define COMPARE_BY_ORD8       11
#define COMPARE_BY_ORD8_REV   12
#define COMPARE_BY_ORD16      13
#define COMPARE_BY_ORD16_REV  14
#define COMPARE_BY_ORD32      15
#define COMPARE_BY_ORD32_REV  16
#define AUTO_ACCEPT           17
#define AUTO_REJECT           18 
#define AUTO_TIE              19
#define ACTIONS_MASK          0x1F

/* Pick an action based on a SortRule and if needed, a SortCache. */
static i8_t
S_derive_action(SortRule *rule, SortCache *sort_cache);

/* Decide whether a doc should be inserted into the HitQueue. */
static INLINE bool_t
SI_competitive(SortCollector *self, i32_t doc_id);

SortCollector*
SortColl_new(Schema *schema, SortSpec *sort_spec, u32_t wanted) 
{
    SortCollector *self = (SortCollector*)VTable_Make_Obj(SORTCOLLECTOR);
    return SortColl_init(self, schema, sort_spec, wanted);
}

/* Default to sort-by-score-then-doc-id. */
static VArray*
S_default_sort_rules()
{
    VArray *rules = VA_new(1);
    VA_Push(rules, (Obj*)SortRule_new(SortRule_SCORE, NULL, false));
    VA_Push(rules, (Obj*)SortRule_new(SortRule_DOC_ID, NULL, false));
    return rules;
}

SortCollector*
SortColl_init(SortCollector *self, Schema *schema, SortSpec *sort_spec,
              u32_t wanted)
{
    VArray *rules   = sort_spec 
                    ? (VArray*)INCREF(SortSpec_Get_Rules(sort_spec))
                    : S_default_sort_rules();
    u32_t num_rules = VA_Get_Size(rules);
    u32_t i;

    /* Validate. */
    if (sort_spec && !schema) {
        THROW(ERR, "Can't supply a SortSpec without a Schema.");
    }
    if (!num_rules) {
        THROW(ERR, "Can't supply a SortSpec with no SortRules.");
    }

    /* Init. */
    Coll_init((Collector*)self);
    self->total_hits    = 0;
    self->bubble_doc    = I32_MAX;
    self->bubble_score  = F32_NEGINF;
    self->seg_doc_max   = 0;

    /* Assign. */
    self->wanted        = wanted;

    /* Derive. */
    self->hit_q         = HitQ_new(schema, sort_spec, wanted);
    self->rules         = rules; /* absorb refcount. */
    self->num_rules     = num_rules;
    self->sort_caches   = (SortCache**)CALLOCATE(num_rules, sizeof(SortCache*));
    self->ord_arrays    = (void**)CALLOCATE(num_rules, sizeof(void*));
    self->actions       = (u8_t*)CALLOCATE(num_rules, sizeof(u8_t));

    /* Build up an array of "actions" which we will execute during each call
     * to Collect(). Determine whether we need to track scores and field
     * values. */
    self->need_score  = false;
    self->need_values = false;
    for (i = 0; i < num_rules; i++) {
        SortRule *rule   = (SortRule*)VA_Fetch(rules, i);
        i32_t rule_type  = SortRule_Get_Type(rule);
        self->actions[i] = S_derive_action(rule, NULL);
        if  (rule_type == SortRule_SCORE) { 
            self->need_score = true; 
        }
        else if (rule_type == SortRule_FIELD) { 
            CharBuf *field = SortRule_Get_Field(rule);
            FieldType *type = Schema_Fetch_Type(schema, field);
            if (!type || !FType_Sortable(type)) {
                THROW(ERR, "'%o' isn't a sortable field", field);
            }
            self->need_values = true; 
        }
    }

    /* Perform an optimization.  So long as we always collect docs in
     * ascending order, Collect() will favor lower doc numbers -- so we may
     * not need to execute a final COMPARE_BY_DOC_ID action. */
    self->num_actions = num_rules;
    if (self->actions[ num_rules - 1 ] == COMPARE_BY_DOC_ID) {
        self->num_actions--;
    }

    /* Override our derived actions with an action which will be excecuted
     * autmatically until the queue fills up. */
    self->auto_actions    = (u8_t*)MALLOCATE(1);
    self->auto_actions[0] = wanted ? AUTO_ACCEPT : AUTO_REJECT;
    self->derived_actions = self->actions;
    self->actions         = self->auto_actions;


    /* Prepare a MatchDoc-in-waiting. */
    {
        VArray *values = self->need_values ? VA_new(num_rules) : NULL;
        float   score  = self->need_score  ? F32_NEGINF : F32_NAN;
        self->bumped = MatchDoc_new(I32_MAX, score, values);
        DECREF(values);
    }

    return self;
}

void
SortColl_destroy(SortCollector *self) 
{
    DECREF(self->hit_q);
    DECREF(self->rules);
    DECREF(self->bumped);
    FREEMEM(self->sort_caches);
    FREEMEM(self->ord_arrays);
    FREEMEM(self->auto_actions);
    FREEMEM(self->derived_actions);
    SUPER_DESTROY(self, SORTCOLLECTOR);
}

static i8_t
S_derive_action(SortRule *rule, SortCache *cache)
{
    i32_t  rule_type = SortRule_Get_Type(rule);
    bool_t reverse   = !!SortRule_Get_Reverse(rule);

    if (rule_type == SortRule_SCORE) {
        return COMPARE_BY_SCORE + reverse;
    }
    else if (rule_type == SortRule_DOC_ID) {
        return COMPARE_BY_DOC_ID + reverse;
    }
    else if (rule_type == SortRule_FIELD) {
        if (cache) {
            i8_t width = SortCache_Get_Ord_Width(cache);
            switch (width) {
                case 1:  return COMPARE_BY_ORD1  + reverse;
                case 2:  return COMPARE_BY_ORD2  + reverse;
                case 4:  return COMPARE_BY_ORD4  + reverse;
                case 8:  return COMPARE_BY_ORD8  + reverse;
                case 16: return COMPARE_BY_ORD16 + reverse;
                case 32: return COMPARE_BY_ORD32 + reverse;
                default: THROW(ERR, "Unknown width: %i8", width);
            }
        }
        else {
            return AUTO_TIE;
        }
    }
    else {
        THROW(ERR, "Unrecognized SortRule type %i32", rule_type);
    }
    UNREACHABLE_RETURN(i8_t);
}

void
SortColl_set_reader(SortCollector *self, SegReader *reader) 
{
    SortReader *sort_reader 
        = (SortReader*)SegReader_Fetch(reader, VTable_Get_Name(SORTREADER));

    /* Reset threshold variables and trigger auto-action behavior. */
    self->bumped->doc_id = I32_MAX;
    self->bubble_doc     = I32_MAX;
    self->bumped->score  = self->need_score ? F32_NEGINF : F32_NAN;
    self->bubble_score   = self->need_score ? F32_NEGINF : F32_NAN;
    self->actions        = self->auto_actions;

    /* Obtain sort caches. Derive actions array for this segment. */
    if (self->need_values && sort_reader) {
        u32_t i, max;
        for (i = 0, max = self->num_rules; i < max; i++) {
            SortRule  *rule  = (SortRule*)VA_Fetch(self->rules, i);
            CharBuf   *field = SortRule_Get_Field(rule);
            SortCache *cache = field
                             ? SortReader_Fetch_Sort_Cache(sort_reader, field)
                             : NULL;
            self->sort_caches[i] = cache;
            self->derived_actions[i] = S_derive_action(rule, cache);
            if (cache) { self->ord_arrays[i] = SortCache_Get_Ords(cache); }
            else       { self->ord_arrays[i] = NULL; }
        }
    }
    self->seg_doc_max = reader ? SegReader_Doc_Max(reader) : 0;
    Coll_set_reader((Collector*)self, reader);
}

VArray*
SortColl_pop_match_docs(SortCollector *self)
{
    return HitQ_Pop_All(self->hit_q);
}

u32_t
SortColl_get_total_hits(SortCollector *self) { return self->total_hits; }

bool_t
SortColl_need_score(SortCollector *self)
{
    return self->need_score;
}

void
SortColl_collect(SortCollector *self, i32_t doc_id) 
{
    /* Add to the total number of hits. */
    self->total_hits++;
    
    /* Collect this hit if it's competitive. */
    if (SI_competitive(self, doc_id)) {
        MatchDoc *const match_doc = self->bumped;
        match_doc->doc_id = doc_id + self->base;

        if (self->need_score && match_doc->score == F32_NEGINF) {
            match_doc->score = Matcher_Score(self->matcher);
        }

        /* Fetch values so that cross-segment sorting can work. */
        if (self->need_values) {
            VArray *values = match_doc->values;
            u32_t i, max;

            for (i = 0, max = self->num_rules; i < max; i++) {
                SortCache *cache   = self->sort_caches[i];
                Obj       *old_val = (Obj*)VA_Delete(values, i);
                if (cache) {
                    i32_t ord = SortCache_Ordinal(cache, doc_id);
                    Obj *blank = old_val 
                               ? old_val 
                               : SortCache_Make_Blank(cache);
                    Obj *val = SortCache_Value(cache, ord, blank);
                    if (val) { VA_Store(values, i, (Obj*)val); }
                    else { DECREF(blank); }
                }
            }
        }

        /* Insert the new MatchDoc. */
        self->bumped = (MatchDoc*)HitQ_Jostle(self->hit_q, (Obj*)match_doc);

        if (self->bumped) {
            if (self->bumped == match_doc) {
                /* The queue is full, and we have established a threshold for
                 * this segment as to what sort of document is definitely not
                 * acceptable.  Turn off AUTO_ACCEPT and start actually
                 * testing whether hits are competitive. */
                self->bubble_score  = match_doc->score;
                self->bubble_doc    = doc_id;
                self->actions       = self->derived_actions;
            }

            /* Recycle. */
            self->bumped->score = self->need_score ? F32_NEGINF : F32_NAN;
        }
        else {
            /* The queue isn't full yet, so create a fresh MatchDoc. */
            VArray *values = self->need_values 
                           ? VA_new(self->num_rules)
                           : NULL;
            float fake_score = self->need_score ? F32_NEGINF : F32_NAN;
            self->bumped = MatchDoc_new(I32_MAX, fake_score, values);
            DECREF(values);
        }

    }
}

static INLINE i32_t
SI_compare_by_ord1(SortCollector *self, u32_t tick, i32_t a, i32_t b)
{
    void *const ords = self->ord_arrays[tick];
    i32_t a_ord = NumUtil_u1get(ords, a);
    i32_t b_ord = NumUtil_u1get(ords, b);
    return a_ord - b_ord;
}
static INLINE i32_t
SI_compare_by_ord2(SortCollector *self, u32_t tick, i32_t a, i32_t b)
{
    void *const ords = self->ord_arrays[tick];
    i32_t a_ord = NumUtil_u2get(ords, a);
    i32_t b_ord = NumUtil_u2get(ords, b);
    return a_ord - b_ord;
}
static INLINE i32_t
SI_compare_by_ord4(SortCollector *self, u32_t tick, i32_t a, i32_t b)
{
    void *const ords = self->ord_arrays[tick];
    i32_t a_ord = NumUtil_u4get(ords, a);
    i32_t b_ord = NumUtil_u4get(ords, b);
    return a_ord - b_ord;
}
static INLINE i32_t
SI_compare_by_ord8(SortCollector *self, u32_t tick, i32_t a, i32_t b)
{
    u8_t *ords = (u8_t*)self->ord_arrays[tick];
    i32_t a_ord = ords[a];
    i32_t b_ord = ords[b];
    return a_ord - b_ord;
}
static INLINE i32_t
SI_compare_by_ord16(SortCollector *self, u32_t tick, i32_t a, i32_t b)
{
    u16_t *ords = (u16_t*)self->ord_arrays[tick];
    i32_t a_ord = ords[a];
    i32_t b_ord = ords[b];
    return a_ord - b_ord;
}
static INLINE i32_t
SI_compare_by_ord32(SortCollector *self, u32_t tick, i32_t a, i32_t b)
{
    i32_t *ords = (i32_t*)self->ord_arrays[tick];
    return ords[a] - ords[b];
}

/* Bounds checking for doc id against the segment doc_max.  We assume that any
 * sort cache ord arrays can accomodate lookups up to this number. */
static INLINE i32_t
SI_validate_doc_id(SortCollector *self, i32_t doc_id)
{
    /* Check as u32_t since we're using these doc ids as array indexes. */
    if ((u32_t)doc_id > (u32_t)self->seg_doc_max) {
        THROW(ERR, "Doc ID %i32 greater than doc max %i32", doc_id, 
            self->seg_doc_max);
    }
    return doc_id;
}

static INLINE bool_t
SI_competitive(SortCollector *self, i32_t doc_id)
{
    /* Ordinarily, we would cache local copies of more member variables in
     * const automatic variables in order to improve code clarity and provide
     * more hints to the compiler about what variables are actually invariant
     * for the duration of this routine:
     * 
     *     u8_t *const actions    = self->actions;
     *     const u32_t num_rules  = self->num_rules;
     *     const i32_t bubble_doc = self->bubble_doc;
     *
     * However, our major goal is to return as quickly as possible, and the
     * common case is that we'll have our answer before the first loop iter
     * finishes -- so we don't worry about the cost of performing extra
     * dereferencing on subsequent loop iters.
     *
     * The goal of returning quickly also drives the choice of a "do-while"
     * loop instead of a "for" loop, and the switch statement optimized for
     * compilation to a jump table.
     */
    u8_t *const actions = self->actions;
    u32_t i = 0;

    /* Iterate through our array of actions, returning as quickly as
     * possible. */
    do {
        switch (actions[i] & ACTIONS_MASK) {
            case AUTO_ACCEPT:
                return true;
            case AUTO_REJECT:
                return false;
            case AUTO_TIE:
                break;
            case COMPARE_BY_SCORE: {
                    float score = Matcher_Score(self->matcher);
                    if  (score > self->bubble_score) {
                        self->bumped->score = score;
                        return true;
                    }
                    else if (score < self->bubble_score) {
                        return false;
                    }
                }
                break;
            case COMPARE_BY_SCORE_REV: {
                    float score = Matcher_Score(self->matcher);
                    if  (score < self->bubble_score) {
                        self->bumped->score = score;
                        return true;
                    }
                    else if (score > self->bubble_score) {
                        return false;
                    }
                }
                break;
            case COMPARE_BY_DOC_ID:
                if      (doc_id > self->bubble_doc) { return false; }
                else if (doc_id < self->bubble_doc) { return true; }
                break;
            case COMPARE_BY_DOC_ID_REV:
                if      (doc_id > self->bubble_doc) { return true; }
                else if (doc_id < self->bubble_doc) { return false; }
                break;
            case COMPARE_BY_ORD1: {
                    i32_t comparison = SI_compare_by_ord1(self, i,
                        SI_validate_doc_id(self, doc_id), self->bubble_doc);
                    if      (comparison < 0) { return true; }
                    else if (comparison > 0) { return false; }
                }
                break;
            case COMPARE_BY_ORD1_REV: {
                    i32_t comparison = SI_compare_by_ord1(self, i,
                        self->bubble_doc, SI_validate_doc_id(self, doc_id));
                    if      (comparison < 0) { return true; }
                    else if (comparison > 0) { return false; }
                }
                break;
            case COMPARE_BY_ORD2: {
                    i32_t comparison = SI_compare_by_ord2(self, i,
                        SI_validate_doc_id(self, doc_id), self->bubble_doc);
                    if      (comparison < 0) { return true; }
                    else if (comparison > 0) { return false; }
                }
                break;
            case COMPARE_BY_ORD2_REV: {
                    i32_t comparison = SI_compare_by_ord2(self, i,
                        self->bubble_doc, SI_validate_doc_id(self, doc_id));
                    if      (comparison < 0) { return true; }
                    else if (comparison > 0) { return false; }
                }
                break;
            case COMPARE_BY_ORD4: {
                    i32_t comparison = SI_compare_by_ord4(self, i,
                        SI_validate_doc_id(self, doc_id), self->bubble_doc);
                    if      (comparison < 0) { return true; }
                    else if (comparison > 0) { return false; }
                }
                break;
            case COMPARE_BY_ORD4_REV: {
                    i32_t comparison = SI_compare_by_ord4(self, i,
                        self->bubble_doc, SI_validate_doc_id(self, doc_id));
                    if      (comparison < 0) { return true; }
                    else if (comparison > 0) { return false; }
                }
                break;
            case COMPARE_BY_ORD8: {
                    i32_t comparison = SI_compare_by_ord8(self, i,
                        SI_validate_doc_id(self, doc_id), self->bubble_doc);
                    if      (comparison < 0) { return true; }
                    else if (comparison > 0) { return false; }
                }
                break;
            case COMPARE_BY_ORD8_REV: {
                    i32_t comparison = SI_compare_by_ord8(self, i,
                        self->bubble_doc, SI_validate_doc_id(self, doc_id));
                    if      (comparison < 0) { return true; }
                    else if (comparison > 0) { return false; }
                }
                break;
            case COMPARE_BY_ORD16: {
                    i32_t comparison = SI_compare_by_ord16(self, i,
                        SI_validate_doc_id(self, doc_id), self->bubble_doc);
                    if      (comparison < 0) { return true; }
                    else if (comparison > 0) { return false; }
                }
                break;
            case COMPARE_BY_ORD16_REV: {
                    i32_t comparison = SI_compare_by_ord16(self, i,
                        self->bubble_doc, SI_validate_doc_id(self, doc_id));
                    if      (comparison < 0) { return true; }
                    else if (comparison > 0) { return false; }
                }
                break;
            case COMPARE_BY_ORD32: {
                    i32_t comparison = SI_compare_by_ord32(self, i,
                        SI_validate_doc_id(self, doc_id), self->bubble_doc);
                    if      (comparison < 0) { return true; }
                    else if (comparison > 0) { return false; }
                }
                break;
            case COMPARE_BY_ORD32_REV: {
                    i32_t comparison = SI_compare_by_ord32(self, i,
                        self->bubble_doc, SI_validate_doc_id(self, doc_id));
                    if      (comparison < 0) { return true; }
                    else if (comparison > 0) { return false; }
                }
                break;
            default:
                THROW(ERR, "UNEXPECTED action %u8", actions[i]);
        }
    } while (++i < self->num_actions);

    /* If we've made it this far and we're still tied, reject the doc so that
     * we prefer items already in the queue.  This has the effect of
     * implicitly breaking ties by doc num, since docs are collected in order.
     */
    return false;
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
