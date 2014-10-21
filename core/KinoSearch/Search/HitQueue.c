#define C_KINO_HITQUEUE
#define C_KINO_MATCHDOC
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/HitQueue.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/SortCache.h"
#include "KinoSearch/Plan/FieldType.h"
#include "KinoSearch/Plan/Schema.h"
#include "KinoSearch/Search/MatchDoc.h"
#include "KinoSearch/Search/SortRule.h"
#include "KinoSearch/Search/SortSpec.h"


#define COMPARE_BY_SCORE      1
#define COMPARE_BY_SCORE_REV  2
#define COMPARE_BY_DOC_ID     3
#define COMPARE_BY_DOC_ID_REV 4
#define COMPARE_BY_VALUE      5
#define COMPARE_BY_VALUE_REV  6
#define ACTIONS_MASK          0xF

HitQueue*
HitQ_new(Schema *schema, SortSpec *sort_spec, uint32_t wanted) 
{
    HitQueue *self = (HitQueue*)VTable_Make_Obj(HITQUEUE);
    return HitQ_init(self, schema, sort_spec, wanted);
}

HitQueue*
HitQ_init(HitQueue *self, Schema *schema, SortSpec *sort_spec, uint32_t wanted)
{
    if (sort_spec) {
        uint32_t i;
        VArray *rules      = SortSpec_Get_Rules(sort_spec);
        uint32_t   num_rules  = VA_Get_Size(rules);
        uint32_t   action_num = 0;

        if (!schema) {
            THROW(ERR, "Can't supply sort_spec without schema");
        }

        self->need_values = false;
        self->num_actions = num_rules;
        self->actions     = (uint8_t*)MALLOCATE(num_rules * sizeof(uint8_t));
        self->field_types = (FieldType**)CALLOCATE(num_rules, sizeof(FieldType*));

        for (i = 0; i < num_rules; i++) {
            SortRule *rule      = (SortRule*)VA_Fetch(rules, i);
            int32_t   rule_type = SortRule_Get_Type(rule);
            bool_t    reverse   = SortRule_Get_Reverse(rule);

            if (rule_type == SortRule_SCORE) {
                self->actions[action_num++] = reverse 
                                            ? COMPARE_BY_SCORE_REV
                                            : COMPARE_BY_SCORE;
            }
            else if (rule_type == SortRule_DOC_ID) {
                self->actions[action_num++] = reverse 
                                            ? COMPARE_BY_DOC_ID_REV
                                            : COMPARE_BY_DOC_ID;
            }
            else if (rule_type == SortRule_FIELD) {
                CharBuf   *field = SortRule_Get_Field(rule);
                FieldType *type  = Schema_Fetch_Type(schema, field);
                if (type) {
                    self->field_types[action_num] = (FieldType*)INCREF(type);
                    self->actions[action_num++] = reverse 
                                                ? COMPARE_BY_VALUE_REV
                                                : COMPARE_BY_VALUE;
                    self->need_values = true;
                }
                else { 
                    // Skip over fields we don't know how to sort on. 
                    continue; 
                } 
            }
            else {
                THROW(ERR, "Unknown SortRule type: %i32", rule_type);
            }
        }
    }
    else {
        self->num_actions = 2;
        self->actions     = (uint8_t*)MALLOCATE(self->num_actions * sizeof(uint8_t));
        self->actions[0]  = COMPARE_BY_SCORE;
        self->actions[1]  = COMPARE_BY_DOC_ID;
    }

    return (HitQueue*)PriQ_init((PriorityQueue*)self, wanted);
}

void
HitQ_destroy(HitQueue *self)
{
    FieldType **types = self->field_types;
    FieldType **const limit = types + self->num_actions - 1;
    for ( ; types < limit; types++) { 
        if (types) { DECREF(*types); }
    }
    FREEMEM(self->actions);
    FREEMEM(self->field_types);
    SUPER_DESTROY(self, HITQUEUE);
}

Obj*
HitQ_jostle(HitQueue *self, Obj *element)
{
    MatchDoc *match_doc = (MatchDoc*)CERTIFY(element, MATCHDOC);
    HitQ_jostle_t super_jostle 
        = (HitQ_jostle_t)SUPER_METHOD(HITQUEUE, HitQ, Jostle);
    if (self->need_values) {
        CERTIFY(match_doc->values, VARRAY);
    }
    return super_jostle(self, element);
}

static INLINE int32_t
SI_compare_by_value(HitQueue *self, uint32_t tick, MatchDoc *a, MatchDoc *b)
{
    Obj *a_val = VA_Fetch(a->values, tick);
    Obj *b_val = VA_Fetch(b->values, tick);
    FieldType *field_type = self->field_types[tick];
    return FType_null_back_compare_values(field_type, a_val, b_val);
}

bool_t
HitQ_less_than(HitQueue *self, Obj *obj_a, Obj *obj_b) 
{
    MatchDoc *const a = (MatchDoc*)obj_a;
    MatchDoc *const b = (MatchDoc*)obj_b;
    uint32_t i = 0;
    uint8_t *const actions = self->actions;

    do {
        switch (actions[i] & ACTIONS_MASK) {
            case COMPARE_BY_SCORE:
                // Prefer high scores. 
                if      (a->score > b->score) { return false;   }
                else if (a->score < b->score) { return true;    }
                break;
            case COMPARE_BY_SCORE_REV:
                if      (a->score > b->score) { return true;    }
                else if (a->score < b->score) { return false;   }
                break;
            case COMPARE_BY_DOC_ID:
                // Prefer low doc ids. 
                if      (a->doc_id > b->doc_id) { return true;    }
                else if (a->doc_id < b->doc_id) { return false;   }
                break;
            case COMPARE_BY_DOC_ID_REV:     
                if      (a->doc_id > b->doc_id) { return false;    }
                else if (a->doc_id < b->doc_id) { return true;   }
                break;
            case COMPARE_BY_VALUE: {
                    int32_t comparison = SI_compare_by_value(self, i, a, b);
                    if      (comparison > 0) { return true; }
                    else if (comparison < 0) { return false; }
                }
                break;
            case COMPARE_BY_VALUE_REV: {
                    int32_t comparison = SI_compare_by_value(self, i, b, a);
                    if      (comparison > 0) { return true; }
                    else if (comparison < 0) { return false; }
                }
                break;
            default:         
                THROW(ERR, "Unexpected action %u8", actions[i]);
        }

    } while (++i < self->num_actions);

    return false;
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

