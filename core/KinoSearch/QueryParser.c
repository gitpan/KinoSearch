#include <stdlib.h>
#include <ctype.h>
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/QueryParser.h"
#include "KinoSearch/Analysis/Analyzer.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/FieldType/FullTextType.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Search/LeafQuery.h"
#include "KinoSearch/Search/ANDQuery.h"
#include "KinoSearch/Search/MatchAllQuery.h"
#include "KinoSearch/Search/NoMatchQuery.h"
#include "KinoSearch/Search/NOTQuery.h"
#include "KinoSearch/Search/ORQuery.h"
#include "KinoSearch/Search/PhraseQuery.h"
#include "KinoSearch/Search/RequiredOptionalQuery.h"
#include "KinoSearch/Search/TermQuery.h"
#include "KinoSearch/Search/Query.h"
 
#define SHOULD            0x00000001
#define MUST              0x00000002
#define MUST_NOT          0x00000004
#define TOKEN_OPEN_PAREN  0x00000008
#define TOKEN_CLOSE_PAREN 0x00000010
#define TOKEN_MINUS       0x00000020
#define TOKEN_PLUS        0x00000040
#define TOKEN_NOT         0x00000080
#define TOKEN_OR          0x00000100
#define TOKEN_AND         0x00000200
#define TOKEN_FIELD       0x00000400
#define TOKEN_QUERY       0x00000800

/* Recursing helper function for Tree(). */
static Query*
S_do_tree(QueryParser *self, CharBuf *query_string, CharBuf *default_field, 
          Hash *extractions);

/* A function that attempts to match a substring and if successful, stores the
 * begin and end of the match in the supplied pointers and returns true.
 */
typedef bool_t
(*kino_QueryParser_match_t)(CharBuf *input, char **begin_match, 
                            char **end_match);
#define match_t kino_QueryParser_match_t

/* Find a quote/end-of-string -delimited phrase.
 */
static bool_t
S_match_phrase(CharBuf *input, char**begin_match, char **end_match);

/* Find a non-nested parethetical group.
 */
static bool_t
S_match_bool_group(CharBuf *input, char**begin_match, char **end_match);

/* Replace whatever match() matches with a label, storing the matched text as
 * a CharBuf in the supplied storage Hash.
 */
static CharBuf*
S_extract_something(QueryParser *self, const CharBuf *query_string, 
                    CharBuf *label, Hash *extractions, match_t match);

/* Symbolically replace phrases in a query string. */
static CharBuf*
S_extract_phrases(QueryParser *self, const CharBuf *query_string, 
                  Hash *extractions);

/* Symbolically replace parenthetical groupings in a query string. */
static CharBuf*
S_extract_paren_groups(QueryParser *self, const CharBuf *query_string, 
                       Hash *extractions);

/* Consume text and possibly following whitespace, if there's a match and the
 * matching is bordered on the right by either whitespace or the end of the
 * string.
 */
static bool_t
S_consume_ascii_token(ViewCharBuf *qstring, char *ptr, size_t size);

/* Consume the supplied text if there's a match.  */
static bool_t
S_consume_ascii(ViewCharBuf *qstring, char *ptr, size_t size);

/* Consume what looks like a field name followed by a colon.  */
static bool_t
S_consume_field(ViewCharBuf *qstring, ViewCharBuf *target);

/* Consume non-whitespace from qstring and store the match in target. */
static bool_t
S_consume_non_whitespace(ViewCharBuf *qstring, ViewCharBuf *target);

#define RAND_STRING_LEN      16
#define PHRASE_LABEL_LEN     (RAND_STRING_LEN + sizeof("_phrase") - 1)
#define BOOL_GROUP_LABEL_LEN (RAND_STRING_LEN + sizeof("_bool_group") - 1)

QueryParser*
QParser_new(Schema *schema, Analyzer *analyzer, const CharBuf *default_boolop,
            VArray *fields)
{
    QueryParser *self = (QueryParser*)VTable_Make_Obj(&QUERYPARSER);
    return QParser_init(self, schema, analyzer, default_boolop, fields);
}

QueryParser*
QParser_init(QueryParser *self, Schema *schema, Analyzer *analyzer,
             const CharBuf *default_boolop, VArray *fields)
{
    u32_t i;

    /* Init. */
    self->heed_colons = false;
    self->label_inc   = 0;

    /* Assign. */
    self->schema         = (Schema*)INCREF(schema);
    self->analyzer       = analyzer ? (Analyzer*)INCREF(analyzer) : NULL;
    self->default_boolop = default_boolop
                         ? CB_Clone(default_boolop)
                         : CB_new_from_trusted_utf8("OR", 2);
    
    if (fields) {
        u32_t i, max;
        self->fields = VA_Shallow_Copy(fields);
        for (i = 0, max = VA_Get_Size(fields); i < max; i++) {
            ASSERT_IS_A(VA_Fetch(fields, i), CHARBUF);
        }
        VA_Sort(self->fields, NULL, NULL);
    }
    else {
        u32_t i;
        VArray *all_fields = Schema_All_Fields(schema);
        u32_t num_fields = VA_Get_Size(all_fields);
        self->fields = VA_new(num_fields);
        for (i = 0; i < num_fields; i++) {
            CharBuf *field = (CharBuf*)VA_Fetch(all_fields, i);
            FieldType *type = Schema_Fetch_Type(schema, field);
            if (type && FType_Indexed(type)) {
                VA_Push(self->fields, INCREF(field)); 
            }
        }
        DECREF(all_fields);
    }
    VA_Sort(self->fields, NULL, NULL);

    if ( !(   CB_Equals_Str(self->default_boolop, "OR", 2)
           || CB_Equals_Str(self->default_boolop, "AND", 3)) 
    ) {
        THROW("Invalid value for default_boolop: %o", self->default_boolop);
    }

    /* Create string labels that presumably won't appear in a search. */
    self->phrase_label     = CB_new_from_trusted_utf8("_phrase", 7);
    self->bool_group_label = CB_new_from_trusted_utf8("_bool_group", 11);
    CB_Grow(self->phrase_label, PHRASE_LABEL_LEN + 5);
    CB_Grow(self->bool_group_label, BOOL_GROUP_LABEL_LEN + 5);
    for (i = 0; i < RAND_STRING_LEN; i++) {
        char rand_char = (rand() % 26) + 'A';
        CB_Cat_Trusted_Str(self->phrase_label, &rand_char, 1);
        CB_Cat_Trusted_Str(self->bool_group_label, &rand_char, 1);
    }

    return self;
}

void
QParser_destroy(QueryParser *self)
{
    DECREF(self->schema);
    DECREF(self->analyzer);
    DECREF(self->default_boolop);
    DECREF(self->fields);
    DECREF(self->phrase_label);
    DECREF(self->bool_group_label);
    FREE_OBJ(self);
}

Analyzer*
QParser_get_analyzer(QueryParser *self)       { return self->analyzer; }
Schema*
QParser_get_schema(QueryParser *self)         { return self->schema; }
CharBuf*
QParser_get_default_boolop(QueryParser *self) { return self->default_boolop; }
VArray*
QParser_get_fields(QueryParser *self)         { return self->fields; }
bool_t
QParser_heed_colons(QueryParser *self)        { return self->heed_colons; }
void
QParser_set_heed_colons(QueryParser *self, bool_t heed_colons) 
    { self->heed_colons = heed_colons; }


Query*
QParser_parse(QueryParser *self, const CharBuf *query_string)
{
    CharBuf *qstring = query_string 
                     ? CB_Clone(query_string) 
                     : CB_new_from_trusted_utf8("", 0);
    Query *tree = QParser_tree(self, qstring);
    Query *expanded = QParser_expand(self, tree);
    Query *pruned = QParser_prune(self, expanded);
    DECREF(expanded);
    DECREF(tree);
    DECREF(qstring);
    return pruned;
}

Query*
QParser_tree(QueryParser *self, const CharBuf *query_string)
{
    Hash    *extractions = Hash_new(0);
    CharBuf *mod1        = S_extract_phrases(self, query_string, extractions);
    CharBuf *mod2        = S_extract_paren_groups(self, mod1, extractions);
    Query   *retval      = S_do_tree(self, mod2, NULL, extractions);
    DECREF(mod2);
    DECREF(mod1);
    DECREF(extractions);
    return retval;
}

static VArray*
S_parse_flat_string(QueryParser *self, CharBuf *query_string)
{
    VArray      *parse_tree       = VA_new(0);
    CharBuf     *qstring_copy     = CB_Clone(query_string);
    ViewCharBuf  qstring          = ZCB_BLANK;
    bool_t       need_close_paren = false;

    ViewCB_Assign(&qstring, qstring_copy);
    ViewCB_Trim(&qstring);

    if (S_consume_ascii(&qstring, "(", 1)) {
        VA_Push(parse_tree, (Obj*)ParserToken_new(TOKEN_OPEN_PAREN, NULL, 0));
        if (ViewCB_Code_Point_From(&qstring, 1) == ')') {
            need_close_paren = true;
            ViewCB_Chop(&qstring, 1);
        }
    }

    while (CB_Get_Size(&qstring)) {
        ViewCharBuf  temp  = ZCB_BLANK;
        ParserToken *token = NULL;

        if (ViewCB_Trim_Top(&qstring)) { 
            /* Fast-forward past whitespace. */
            continue;
        }
        else if (S_consume_ascii(&qstring, "+", 1)) {
            token = ParserToken_new(TOKEN_PLUS, NULL, 0);
        }
        else if (S_consume_ascii(&qstring, "-", 1)) {
            token = ParserToken_new(TOKEN_MINUS, NULL, 0);
        }
        else if (S_consume_ascii_token(&qstring, "AND", 3)) {
            token = ParserToken_new(TOKEN_AND, NULL, 0);
        }
        else if (S_consume_ascii_token(&qstring, "OR", 2)) {
            token = ParserToken_new(TOKEN_OR, NULL, 0);
        }
        else if (S_consume_ascii_token(&qstring, "NOT", 3)) {
            token = ParserToken_new(TOKEN_NOT, NULL, 0);
        }
        else if (self->heed_colons && S_consume_field(&qstring, &temp)) {
            token = ParserToken_new(TOKEN_FIELD, temp.ptr, 
                ViewCB_Get_Size(&temp));
        }
        else if (S_consume_non_whitespace(&qstring, &temp)) {
            token = ParserToken_new(TOKEN_QUERY, temp.ptr,
                ViewCB_Get_Size(&temp));
        }
        else {
            THROW("Failed to parse '%o'", &qstring);
        }

        VA_Push(parse_tree, (Obj*)token);
    }

    if (need_close_paren) {
        VA_Push(parse_tree, 
            (Obj*)ParserToken_new(TOKEN_CLOSE_PAREN, NULL, 0));
    }

    /* Clean up. */
    DECREF(qstring_copy);

    return parse_tree;
}

static void
S_splice_out_token_type(VArray *elems, u32_t token_type_mask)
{
    u32_t i;
    for (i = VA_Get_Size(elems); i--; ) {
        ParserToken *token = (ParserToken*)VA_Fetch(elems, i);
        if (OBJ_IS_A(token, PARSERTOKEN)) {
            if (token->type & token_type_mask) VA_Splice(elems, i, 1);
        }
    }
}

static Query*
S_do_tree(QueryParser *self, CharBuf *query_string, CharBuf *default_field, 
          Hash *extractions)
{
    Query  *retval;
    bool_t  apply_parens   = false;
    u32_t   default_occur  = CB_Equals_Str(self->default_boolop, "AND", 3)
                           ? MUST
                           : SHOULD;
    VArray *elems          = S_parse_flat_string(self, query_string);
    u32_t   i, max;
    
    /* Determine whether this subclause is bracketed by parens. */
    {
        ParserToken *maybe_open_paren = (ParserToken*)VA_Fetch(elems, 0);
        if (   maybe_open_paren != NULL 
            && maybe_open_paren->type == TOKEN_OPEN_PAREN
        ) {
            u32_t num_elems;
            apply_parens = true;
            VA_Splice(elems, 0, 1);
            num_elems = VA_Get_Size(elems);
            if (num_elems) {
                ParserToken *maybe_close_paren 
                    = (ParserToken*)VA_Fetch(elems, num_elems - 1);
                if (maybe_close_paren->type == TOKEN_CLOSE_PAREN) {
                    VA_Splice(elems, num_elems - 1, 1);
                }
            }
        }
    }

    /* Generate all queries.  Apply any fields. */
    for (i = VA_Get_Size(elems); i--; ) {
        CharBuf *field = default_field;
        ParserToken *token = (ParserToken*)VA_Fetch(elems, i);

        /* Apply field. */
        if (i > 0) {
            /* Field specifier must immediately precede any query. */
            ParserToken* maybe_field_token
                = (ParserToken*)VA_Fetch(elems, i - 1);
            if (maybe_field_token->type == TOKEN_FIELD) {
                field = maybe_field_token->text;
            }
        }

        if (token->type == TOKEN_QUERY) {
            /* Generate a LeafQuery from a Phrase. */
            if (CB_Starts_With(token->text, self->phrase_label)) {
                CharBuf *inner_text 
                    = (CharBuf*)Hash_Fetch(extractions, (Obj*)token->text);
                Query *query = (Query*)LeafQuery_new(field, inner_text);
                ParserClause *clause = ParserClause_new(query, default_occur);
                DECREF(Hash_Delete(extractions, (Obj*)token->text));
                VA_Store(elems, i, (Obj*)clause);
                DECREF(query);
            }
            /* Recursively parse parenthetical groupings. */
            else if (CB_Starts_With(token->text, self->bool_group_label)) {
                CharBuf *inner_text 
                    = (CharBuf*)Hash_Fetch(extractions, (Obj*)token->text);
                Query *query 
                    = S_do_tree(self, inner_text, field, extractions);
                DECREF(Hash_Delete(extractions, (Obj*)token->text));
                if (query) {
                    ParserClause *clause 
                        = ParserClause_new(query, default_occur);
                    VA_Store(elems, i, (Obj*)clause);
                    DECREF(query);
                }
            }
            /* What's left is probably a term, so generate a LeafQuery. */
            else {
                Query *query = (Query*)LeafQuery_new(field, token->text);
                ParserClause *clause = ParserClause_new(query, default_occur);
                VA_Store(elems, i, (Obj*)clause);
                DECREF(query);
            }
        }
    }
    S_splice_out_token_type(elems, TOKEN_FIELD | TOKEN_QUERY);

    /* Apply +, -, NOT. */
    for (i = VA_Get_Size(elems); i--; ) {
        ParserClause *clause = (ParserClause*)VA_Fetch(elems, i);
        if (OBJ_IS_A(clause, PARSERCLAUSE)) {
            u32_t j;
            for (j = i; j--; ) {
                ParserToken *token = (ParserToken*)VA_Fetch(elems, j);
                if (OBJ_IS_A(token, PARSERTOKEN)) {
                    if (   token->type == TOKEN_MINUS
                        || token->type == TOKEN_NOT
                    ) {
                        clause->occur = clause->occur == MUST_NOT 
                                      ? MUST
                                      : MUST_NOT;
                    }
                    else if (token->type == TOKEN_PLUS) {
                        if (clause->occur == SHOULD) {
                            clause->occur = MUST;
                        }
                    }
                }
                else {
                    break;
                }
            }
        }
    }
    S_splice_out_token_type(elems, TOKEN_PLUS | TOKEN_MINUS | TOKEN_NOT);

    /* Wrap negated queries with NOTQuery objects. */
    for (i = 0, max = VA_Get_Size(elems); i < max; i++) {
        ParserClause *clause = (ParserClause*)VA_Fetch(elems, i);
        if (OBJ_IS_A(clause, PARSERCLAUSE) && clause->occur == MUST_NOT) {
            Query *not_query = QParser_Make_NOT_Query(self, clause->query);
            DECREF(clause->query);
            clause->query = not_query;
        }
    }

    /* Silently discard non-sensical combos of AND and OR, e.g. 
     * 'OR a AND AND OR b AND'. */
    for (i = 0, max = VA_Get_Size(elems); i < max; i++) {
        ParserToken *token = (ParserToken*)VA_Fetch(elems, i);
        if (OBJ_IS_A(token, PARSERTOKEN)) {
            u32_t j, jmax;
            u32_t num_to_zap = 0;
            ParserClause *preceding = (ParserClause*)VA_Fetch(elems, i - 1);
            ParserClause *following = (ParserClause*)VA_Fetch(elems, i + 1);
            if (!preceding || !OBJ_IS_A(preceding, PARSERCLAUSE)) {
                num_to_zap = 1;
            }
            if (!following || !OBJ_IS_A(following, PARSERCLAUSE)) {
                num_to_zap = 1;
            }
            for (j = i + 1, jmax = VA_Get_Size(elems); j < jmax; j++) {
                ParserClause *clause = (ParserClause*)VA_Fetch(elems, j);
                if (OBJ_IS_A(clause, PARSERCLAUSE)) break;
                else num_to_zap++;
            }
            if (num_to_zap) VA_Splice(elems, i, num_to_zap);
        }
    }

    /* Apply AND. */
    for (i = 0; i + 2 < VA_Get_Size(elems); i++) {
        ParserToken *token = (ParserToken*)VA_Fetch(elems, i + 1);
        if (OBJ_IS_A(token, PARSERTOKEN) && token->type == TOKEN_AND) {
            ParserClause *preceding  = (ParserClause*)VA_Fetch(elems, i);
            VArray       *children   = VA_new(2);
            u32_t         num_to_zap = 0;
            u32_t         j, jmax;

            /* Add first clause. */
            VA_Push(children, INCREF(preceding->query));

            /* Add following clauses.  */
            for (j = i + 1, jmax = VA_Get_Size(elems); 
                 j < jmax; 
                 j += 2, num_to_zap+= 2
            ) {
                ParserToken  *maybe_and = (ParserToken*)VA_Fetch(elems, j);
                ParserClause *following 
                    = (ParserClause*)VA_Fetch(elems, j + 1);
                if (   !OBJ_IS_A(maybe_and, PARSERTOKEN)
                    || maybe_and->type != TOKEN_AND
                ) {
                    break;
                }
                else { 
                    ASSERT_IS_A(following, PARSERCLAUSE); 
                } 
                VA_Push(children, INCREF(following->query));
            }
            DECREF(preceding->query);
            preceding->query = QParser_Make_AND_Query(self, children);
            preceding->occur = default_occur;
            DECREF(children);

            VA_Splice(elems, i + 1, num_to_zap);

            /* Don't double wrap '(a AND b)'. */
            if (VA_Get_Size(elems) == 1) apply_parens = false;
        }
    }

    /* Apply OR. */
    for (i = 0; i + 2 < VA_Get_Size(elems); i++) {
        ParserToken *token = (ParserToken*)VA_Fetch(elems, i + 1);
        if (OBJ_IS_A(token, PARSERTOKEN) && token->type == TOKEN_OR) {
            ParserClause *preceding  = (ParserClause*)VA_Fetch(elems, i);
            VArray       *children   = VA_new(2);
            u32_t         num_to_zap = 0;
            u32_t         j, jmax;

            /* Add first clause. */
            VA_Push(children, INCREF(preceding->query));

            /* Add following clauses.  */
            for (j = i + 1, jmax = VA_Get_Size(elems); 
                 j < jmax; 
                 j += 2, num_to_zap+= 2
            ) {
                ParserToken  *maybe_or = (ParserToken*)VA_Fetch(elems, j);
                ParserClause *following 
                    = (ParserClause*)VA_Fetch(elems, j + 1);
                if (   !OBJ_IS_A(maybe_or, PARSERTOKEN)
                    || maybe_or->type != TOKEN_OR
                ) {
                    break;
                }
                else {
                    ASSERT_IS_A(following, PARSERCLAUSE);
                }
                VA_Push(children, INCREF(following->query));
            }
            DECREF(preceding->query);
            preceding->query = QParser_Make_OR_Query(self, children);
            preceding->occur = default_occur;
            DECREF(children);

            VA_Splice(elems, i + 1, num_to_zap);

            /* Don't double wrap '(a OR b)'. */
            if (VA_Get_Size(elems) == 1) apply_parens = false;
        }
    }

    if (VA_Get_Size(elems) == 0) {
        /* No elems means no query. Maybe the search string was something
         * like 'NOT AND' */
        if (apply_parens) {
            retval = default_occur == SHOULD 
                   ? QParser_Make_OR_Query(self, NULL)
                   : QParser_Make_AND_Query(self, NULL);
        }
        else {
            retval = (Query*)NoMatchQuery_new();
        }
    }
    else if (VA_Get_Size(elems) == 1 && !apply_parens) {
        ParserClause *clause = (ParserClause*)VA_Fetch(elems, 0);
        retval = (Query*)INCREF(clause->query);
    }
    else {
        u32_t num_elems = VA_Get_Size(elems);
        VArray *required  = VA_new(num_elems);
        VArray *optional  = VA_new(num_elems);
        VArray *negated   = VA_new(num_elems);
        Query  *req_query = NULL;
        Query  *opt_query = NULL;
        u32_t   i, num_required, num_negated, num_optional;

        /* Demux elems into bins. */
        for (i = 0; i < num_elems; i++) {
            ParserClause *clause = (ParserClause*)VA_Fetch(elems, i);
            if (clause->occur == MUST) 
                VA_Push(required, INCREF(clause->query));
            else if (clause->occur == SHOULD) 
                VA_Push(optional, INCREF(clause->query));
            else if (clause->occur == MUST_NOT)
                VA_Push(negated, INCREF(clause->query));
        }
        num_required = VA_Get_Size(required);
        num_negated  = VA_Get_Size(negated);
        num_optional = VA_Get_Size(optional);

        /* Bind all mandatory matchers together in one Query. */
        if (num_required || num_negated) {
            if (apply_parens || num_required + num_negated > 1) {
                VArray *children = VA_Shallow_Copy(required);
                VA_Push_VArray(children, negated);
                req_query = QParser_Make_AND_Query(self, children);
                DECREF(children);
            }
            else if (num_required) {
                req_query = (Query*)INCREF(VA_Fetch(required, 0));
            }
            else if (num_negated) {
                req_query = (Query*)INCREF(VA_Fetch(negated, 0));
            }
        }
        
        /* Bind all optional matchers together in one Query. */
        if (num_optional) {
            if (!apply_parens && num_optional == 1) {
                opt_query = (Query*)INCREF(VA_Fetch(optional, 0));
            }
            else {
                opt_query = QParser_Make_OR_Query(self, optional);
            }
        }

        /* Unify required and optional. */
        if (req_query && opt_query) {
            if (num_required) { /* not just negated elems */
                retval = QParser_Make_Req_Opt_Query(self, req_query, 
                    opt_query);
            }
            else {
                /* req_query has only negated queries. */
                VArray *children = VA_new(2);
                VA_Push(children, INCREF(req_query));
                VA_Push(children, INCREF(opt_query));
                retval = QParser_Make_AND_Query(self, children);
                DECREF(children);
            }
        }
        else if (opt_query) {
            /* Only optional elems. */
            retval = (Query*)INCREF(opt_query);
        }
        else if (req_query) {
            /* Only required elems. */
            retval = (Query*)INCREF(req_query);
        }
        else {
            retval = NULL; /* kill "uninitialized" compiler warning */
            THROW("Unexpected error");
        }

        DECREF(opt_query);
        DECREF(req_query);
        DECREF(negated);
        DECREF(optional);
        DECREF(required);
    }

    DECREF(elems);

    return retval;
}

static bool_t
S_has_valid_clauses(Query *query)
{
    if (OBJ_IS_A(query, NOTQUERY)) return false;
    else if (OBJ_IS_A(query, MATCHALLQUERY)) return false;
    else if (OBJ_IS_A(query, ORQUERY) || OBJ_IS_A(query, ANDQUERY)) {
        PolyQuery *polyquery = (PolyQuery*)query;
        u32_t i, max;
        for (i = 0, max = VA_Get_Size(polyquery->children); i < max; i++) {
            Query *child = (Query*)VA_Fetch(polyquery->children, i);
            if (S_has_valid_clauses(child)) return true;
        }
        return false;
    }
    return true;
}

static void
S_do_prune(QueryParser *self, Query *query)
{
    if (OBJ_IS_A(query, NOTQUERY)) {
        /* Don't allow double negatives. */
        NOTQuery *not_query = (NOTQuery*)query;
        Query *neg_query = NOTQuery_Get_Negated_Query(not_query);
        if (   !OBJ_IS_A(neg_query, MATCHALLQUERY) 
            && !S_has_valid_clauses(neg_query)
        ) {
            MatchAllQuery *matchall = MatchAllQuery_new();
            NOTQuery_Set_Negated_Query(not_query, (Query*)matchall);
            DECREF(matchall);
        }
    }
    else if (OBJ_IS_A(query, POLYQUERY)) {
        PolyQuery *polyquery = (PolyQuery*)query;
        u32_t i, max;

        /* Recurse. */
        for (i = 0, max = VA_Get_Size(polyquery->children); i < max; i++) {
            Query *child = (Query*)VA_Fetch(polyquery->children, i);
            S_do_prune(self, child);
        }

        if (   OBJ_IS_A(query, REQUIREDOPTIONALQUERY)
            || OBJ_IS_A(query, ORQUERY)
        ) {
            /* Don't allow 'foo OR (-bar)'. */
            VArray *children = ((PolyQuery*)query)->children;
            for (i = 0, max = VA_Get_Size(children); i < max; i++) {
                Query *child = (Query*)VA_Fetch(children, i);
                if (!S_has_valid_clauses(child)) {
                    VA_Store(children, i, (Obj*)NoMatchQuery_new());
                }
            }
        }
        else if (OBJ_IS_A(query, ANDQUERY)) {
            /* Don't allow '(-bar AND -baz)'. */
            if (!S_has_valid_clauses(query)) {
                VArray *children = ((ANDQuery*)query)->children;
                VA_Clear(children);
            }
        }
    }
}

Query*
QParser_prune(QueryParser *self, Query *query)
{
    if (   !query 
        || OBJ_IS_A(query, NOTQUERY) 
        || OBJ_IS_A(query, MATCHALLQUERY)
    ) {
        return (Query*)NoMatchQuery_new();
    }
    else if (OBJ_IS_A(query, POLYQUERY)) {
        S_do_prune(self, query);
    }
    return (Query*)INCREF(query);
}

static bool_t
S_consume_ascii(ViewCharBuf *qstring, char *ptr, size_t len)
{
    if (ViewCB_Starts_With_Str(qstring, ptr, len)) {
        ViewCB_Nip(qstring, len);
        return true;
    }
    return false;
}

static bool_t
S_consume_ascii_token(ViewCharBuf *qstring, char *ptr, size_t len)
{
    if (ViewCB_Starts_With_Str(qstring, ptr, len)) {
        if (   len == ViewCB_Get_Size(qstring)
            || StrHelp_is_whitespace(ViewCB_Code_Point_At(qstring, len))
        ) {
            ViewCB_Nip(qstring, len);
            ViewCB_Trim_Top(qstring);
            return true;
        }
    }
    return false;
}

static bool_t
S_consume_field(ViewCharBuf *qstring, ViewCharBuf *target)
{
    size_t tick = 0;

    while (1) {
        u32_t code_point = ViewCB_Code_Point_At(qstring, tick);
        if (isalnum(code_point) || code_point == '_') tick++;
        else if (code_point == ':') { tick++; break; }
        else return false;
    }

    if (tick == 1) { /* just the colon */
        return false; 
    }
    else {
        ViewCB_Assign(target, (CharBuf*)qstring);
        ViewCB_Set_Size(target, tick - 1);
        if (ViewCB_Starts_With_Str(qstring, "http:", 5)) {
            return false;
        }
        else {
            ViewCB_Nip(qstring, tick);
            return true;
        }
    }
}

static bool_t
S_consume_non_whitespace(ViewCharBuf *qstring, ViewCharBuf *target)
{
    char *ptr = qstring->ptr;
    char *const end = CBEND(qstring);
    while (ptr < end) {
        u32_t code_point = StrHelp_decode_utf8_char(ptr);
        if (StrHelp_is_whitespace(code_point)) break;
        ptr += UTF8_SKIP[*(u8_t*)ptr];
    }
    if (ptr == qstring->ptr) {
        return false;
    }
    else {
        target->ptr = qstring->ptr;
        ViewCB_Set_Size(target, ptr - qstring->ptr);
        qstring->ptr = ptr;
        qstring->ptr = ptr;
        ViewCB_Set_Size(qstring, end - ptr);
        return true;
    }
}

Query*
QParser_expand(QueryParser *self, Query *query)
{
    Query *retval = NULL;

    if (OBJ_IS_A(query, LEAFQUERY)) {
        retval = QParser_Expand_Leaf(self, query);
    }
    else if (OBJ_IS_A(query, ORQUERY) || OBJ_IS_A(query, ANDQUERY)) {
        PolyQuery *polyquery = (PolyQuery*)query;
        VArray *children = PolyQuery_Get_Children(polyquery);
        VArray *new_kids = VA_new(VA_Get_Size(children));
        u32_t i, max;

        for (i = 0, max = VA_Get_Size(children); i < max; i++) {
            Query *child = (Query*)VA_Fetch(children, i);
            Query *new_child = QParser_Expand(self, child); /* recurse */
            if (new_child) VA_Push(new_kids, (Obj*)new_child);
        }
        
        if (VA_Get_Size(new_kids) == 0) {
            retval = (Query*)NoMatchQuery_new();
        }
        else if (VA_Get_Size(new_kids) == 1) {
            retval = (Query*)INCREF(VA_Fetch(new_kids, 0));
        }
        else {
            PolyQuery_Set_Children(polyquery, new_kids);
            retval = (Query*)INCREF(query);
        }

        DECREF(new_kids);
    }
    else if (OBJ_IS_A(query, NOTQUERY)) {
        NOTQuery *not_query = (NOTQuery*)query;
        Query *negated_query = NOTQuery_Get_Negated_Query(not_query);
        negated_query = QParser_Expand(self, negated_query);
        if (negated_query) {
            NOTQuery_Set_Negated_Query(not_query, negated_query);
            DECREF(negated_query);
            retval = (Query*)INCREF(query);
        }
        else {
            retval = (Query*)MatchAllQuery_new();
        }
    }
    else if (OBJ_IS_A(query, REQUIREDOPTIONALQUERY)) {
        RequiredOptionalQuery *req_opt_query = (RequiredOptionalQuery*)query;
        Query *req_query = ReqOptQuery_Get_Required_Query(req_opt_query);
        Query *opt_query = ReqOptQuery_Get_Optional_Query(req_opt_query);

        req_query = QParser_Expand(self, req_query);
        opt_query = QParser_Expand(self, opt_query);

        if (req_query && opt_query) {
            ReqOptQuery_Set_Required_Query(req_opt_query, req_query);
            ReqOptQuery_Set_Optional_Query(req_opt_query, opt_query);
            retval = (Query*)INCREF(query);
        }
        else if (req_query) retval = (Query*)INCREF(req_query);
        else if (opt_query) retval = (Query*)INCREF(opt_query);
        else retval = (Query*)NoMatchQuery_new();

        DECREF(opt_query);
        DECREF(req_query);
    }
    else {
        retval = (Query*)INCREF(query);
    }

    return retval;
}

static CharBuf*
S_unescape(QueryParser *self, CharBuf *orig, CharBuf *target)
{
    ZombieCharBuf source = ZCB_make(orig);
    u32_t code_point;

    if (!self->heed_colons) {
        CB_Copy(target, orig);
        return target;
    }

    CB_Set_Size(target, 0);
    CB_Grow(target, CB_Get_Size(orig) + 4);

    while (0 != (code_point = ZCB_Nip_One(&source))) {
        if (code_point == '\\') {
            u32_t next_code_point = ZCB_Nip_One(&source);
            if (next_code_point == ':') {
                CB_Cat_Char(target, next_code_point);
            }
            else {
                CB_Cat_Char(target, code_point);
                if (next_code_point) { CB_Cat_Char(target, next_code_point); }
            }
        }
        else {
            CB_Cat_Char(target, code_point);
        }
    }

    return target;
}

Query*
QParser_expand_leaf(QueryParser *self, Query *query)
{
    LeafQuery     *leaf_query  = (LeafQuery*)query;
    Schema        *schema      = self->schema; 
    ZombieCharBuf  source_text = ZCB_BLANK;
    CharBuf       *unescaped   = NULL;
    bool_t         is_phrase   = false;
    VArray        *fields;
    VArray        *queries;
    Query         *retval;
    u32_t          i, max;

    /* Determine whether we can actually process the input. */
    if (!OBJ_IS_A(leaf_query, LEAFQUERY)) return NULL;
    if (!CB_Get_Size(LeafQuery_Get_Text(leaf_query))) return NULL;
    else ZCB_Assign(&source_text, LeafQuery_Get_Text(leaf_query));
    unescaped = ZCB_Clone(&source_text);

    /* If quoted, always generate PhraseQuery. */
    ZCB_Trim(&source_text);
    if (ZCB_Code_Point_At(&source_text, 0) == '"') {
        is_phrase = true;
        ZCB_Nip(&source_text, 1);
        if (   ZCB_Code_Point_From(&source_text, 1) == '"'
            && ZCB_Code_Point_From(&source_text, 2) != '\\'
        ) {
            ZCB_Chop(&source_text, 1);
        }
    }

    /* Either use LeafQuery's field or default to Parser's list. */
    if (LeafQuery_Get_Field(leaf_query)) {
        fields = VA_new(1);
        VA_Push(fields, INCREF(LeafQuery_Get_Field(leaf_query)));
    }
    else {
        fields = (VArray*)INCREF(self->fields);
    }

    queries = VA_new(VA_Get_Size(fields));
    for (i = 0, max = VA_Get_Size(fields); i < max; i++) {
        CharBuf   *field    = (CharBuf*)VA_Fetch(fields, i);
        FieldType *type     = Schema_Fetch_Type(schema, field);
        Analyzer  *analyzer = self->analyzer 
                            ? self->analyzer 
                            : Schema_Fetch_Analyzer(schema, field);

        if (!analyzer || (type && !OBJ_IS_A(type, FULLTEXTTYPE))) {
            VA_Push(queries,
                (Obj*)QParser_Make_Term_Query(self, field, 
                    (Obj*)&source_text));
        }
        else {
            /* Extract token texts. */
            CharBuf *split_source 
                = S_unescape(self, (CharBuf*)&source_text, unescaped);
            VArray *maybe_texts = Analyzer_Split(analyzer, split_source);
            u32_t num_maybe_texts = VA_Get_Size(maybe_texts);
            VArray *token_texts = VA_new(num_maybe_texts);
            u32_t j;

            /* Filter out zero-length token texts. */
            for (j = 0; j < num_maybe_texts; j++) {
                CharBuf *token_text = (CharBuf*)VA_Fetch(maybe_texts, j);
                if (CB_Get_Size(token_text)) {
                    VA_Push(token_texts, INCREF(token_text));
                }
            }

            /* Add either a TermQuery or a PhraseQuery. */
            if (is_phrase || VA_Get_Size(token_texts) > 1) {
                VA_Push(queries, (Obj*)
                    QParser_Make_Phrase_Query(self, field, token_texts));
            }
            else if (VA_Get_Size(token_texts) == 1) {
                VA_Push(queries, (Obj*)QParser_Make_Term_Query(self, field,
                    VA_Fetch(token_texts, 0)) );
            }

            DECREF(token_texts);
            DECREF(maybe_texts);
        }
    }

    if (VA_Get_Size(queries) == 0) {
        retval = NULL;
    }
    else if (VA_Get_Size(queries) == 1) {
        retval = (Query*)INCREF(VA_Fetch(queries, 0));
    }
    else {
        retval = QParser_Make_OR_Query(self, queries);
    }

    /* Clean up. */
    DECREF(unescaped);
    DECREF(queries);
    DECREF(fields);

    return retval;
}
 
static CharBuf*
S_extract_something(QueryParser *self, const CharBuf *query_string, 
                    CharBuf *label, Hash *extractions, match_t match) 
{
    char *begin_match;
    char *end_match;
    size_t orig_label_size = CB_Get_Size(label);
    CharBuf *retval  = CB_Clone(query_string);
    
    while (match(retval, &begin_match, &end_match)) {
        size_t len            = end_match - begin_match;
        size_t new_retval_len = len + 1 + (begin_match - retval->ptr) 
                                + (CBEND(retval) - end_match);
        CharBuf *new_retval   = CB_new(new_retval_len);

        /* Store inner text. */
        CB_catf(label, "%u32", self->label_inc++);
        Hash_Store(extractions, (Obj*)label, 
            (Obj*)CB_new_from_utf8(begin_match, len));

        /* Splice the label into the query string. */
        CB_Cat_Str(new_retval, retval->ptr, begin_match - retval->ptr);
        CB_Cat(new_retval, label);
        CB_Cat_Str(new_retval, " ", 1); /* Extra space for safety. */
        CB_Cat_Str(new_retval, end_match, CBEND(retval) - end_match);
        DECREF(retval);
        retval = new_retval;
        CB_Set_Size(label, orig_label_size);
    }

    return retval;
}

static CharBuf*
S_extract_phrases(QueryParser *self, const CharBuf *query_string, 
                  Hash *extractions)
{
    return S_extract_something(self, query_string, self->phrase_label, 
        extractions, S_match_phrase);
}

static bool_t
S_match_phrase(CharBuf *input, char**begin_match, char **end_match)
{
    char *ptr = input->ptr;
    char *const end = CBEND(input);
    for ( ; ptr < end; ptr++) {
        if (*ptr == '"') {
            *begin_match = ptr; 
            *end_match   = end;
            for ( ptr = ptr + 1; ptr < end; ptr++) {
                if (*ptr == '\\') ptr++;
                else if (*ptr == '"') {
                    *end_match = ptr + 1;
                    return true;
                }
            }
            return true;
        }
    }
    return false;
}

static CharBuf*
S_extract_paren_groups(QueryParser *self, const CharBuf *query_string, 
                       Hash *extractions)
{
    return S_extract_something(self, query_string, self->bool_group_label,
        extractions, S_match_bool_group);
}

static bool_t
S_match_bool_group(CharBuf *input, char**begin_match, char **end_match)
{
    char *ptr = input->ptr;
    char *const end = CBEND(input);
    for ( ; ptr < end; ptr++) {
        if (*ptr == '(') {
            FOUND_OPEN_PAREN:
            *begin_match = ptr; 
            *end_match   = end;
            for ( ptr = ptr + 1; ptr < end; ptr++) {
                if (*ptr == '(') goto FOUND_OPEN_PAREN;
                else if (*ptr == ')') {
                    *end_match = ptr + 1;
                    return true;
                }
            }
            return true;
        }
    }
    return false;
}

Query*
QParser_make_term_query(QueryParser *self, const CharBuf *field, Obj *term)
{
    UNUSED_VAR(self);
    return (Query*)TermQuery_new(field, term);
}

Query*
QParser_make_phrase_query(QueryParser *self, const CharBuf *field, 
                         VArray *terms)
{
    UNUSED_VAR(self);
    return (Query*)PhraseQuery_new(field, terms);
}

Query*
QParser_make_or_query(QueryParser *self, VArray *children)
{
    UNUSED_VAR(self);
    return (Query*)ORQuery_new(children);
}

Query*
QParser_make_and_query(QueryParser *self, VArray *children)
{
    UNUSED_VAR(self);
    return (Query*)ANDQuery_new(children);
}

Query*
QParser_make_not_query(QueryParser *self, Query *negated_query)
{
    UNUSED_VAR(self);
    return (Query*)NOTQuery_new(negated_query);
}

Query*
QParser_make_req_opt_query(QueryParser *self, Query *required_query,
                           Query *optional_query)
{
    UNUSED_VAR(self);
    return (Query*)ReqOptQuery_new(required_query, optional_query);
}

/********************************************************************/

ParserClause*
ParserClause_new(Query *query, u32_t occur)
{
    ParserClause *self = (ParserClause*)VTable_Make_Obj(&PARSERCLAUSE);
    return ParserClause_init(self, query, occur);
}

ParserClause*
ParserClause_init(ParserClause *self, Query *query, u32_t occur)
{
    self->query = (Query*)INCREF(query);
    self->occur = occur;
    return self;
}

void
ParserClause_destroy(ParserClause *self)
{
    DECREF(self->query);
    FREE_OBJ(self);
}

/********************************************************************/

ParserToken*
ParserToken_new(u32_t type, const char *text, size_t len)
{
    ParserToken *self = (ParserToken*)VTable_Make_Obj(&PARSERTOKEN);
    return ParserToken_init(self, type, text, len);
}

ParserToken*
ParserToken_init(ParserToken *self, u32_t type, const char *text, size_t len)
{
    self->type = type;
    self->text = text ? CB_new_from_utf8(text, len) : NULL;
    return self;
}

void
ParserToken_destroy(ParserToken *self)
{
    DECREF(self->text);
    FREE_OBJ(self);
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

