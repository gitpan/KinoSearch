#define C_KINO_TESTQUERYPARSERSYNTAX
#define C_KINO_TESTQUERYPARSER
#include "KinoSearch/Util/ToolSet.h"
#include <stdarg.h>
#include <string.h>

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/TestQueryParserSyntax.h"
#include "KinoSearch/Test/TestQueryParser.h"
#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/Search/Hits.h"
#include "KinoSearch/Search/IndexSearcher.h"
#include "KinoSearch/Search/QueryParser.h"
#include "KinoSearch/Search/TermQuery.h"
#include "KinoSearch/Search/PhraseQuery.h"
#include "KinoSearch/Search/LeafQuery.h"
#include "KinoSearch/Search/ANDQuery.h"
#include "KinoSearch/Search/NOTQuery.h"
#include "KinoSearch/Search/ORQuery.h"
#include "KinoSearch/Store/Folder.h"

#define make_term_query   (Query*)kino_TestUtils_make_term_query
#define make_phrase_query (Query*)kino_TestUtils_make_phrase_query
#define make_leaf_query   (Query*)kino_TestUtils_make_leaf_query
#define make_not_query    (Query*)kino_TestUtils_make_not_query
#define make_poly_query   (Query*)kino_TestUtils_make_poly_query

static TestQueryParser*
leaf_test_simple_term()
{
    Query   *tree     = make_leaf_query(NULL, "a");
    Query   *plain_q  = make_term_query("plain", "a");
    Query   *fancy_q  = make_term_query("fancy", "a");
    Query   *expanded = make_poly_query(BOOLOP_OR, fancy_q, plain_q, NULL);
    return TestQP_new("a", tree, expanded, 4);
}

static TestQueryParser*
leaf_test_simple_phrase()
{
    Query   *tree     = make_leaf_query(NULL, "\"a b\"");
    Query   *plain_q  = make_phrase_query("plain", "a", "b", NULL);
    Query   *fancy_q  = make_phrase_query("fancy", "a", "b", NULL);
    Query   *expanded = make_poly_query(BOOLOP_OR, fancy_q, plain_q, NULL);
    return TestQP_new("\"a b\"", tree, expanded, 3);
}

static TestQueryParser*
leaf_test_unclosed_quote()
{
    Query   *tree     = make_leaf_query(NULL, "\"a b");
    Query   *plain_q  = make_phrase_query("plain", "a", "b", NULL);
    Query   *fancy_q  = make_phrase_query("fancy", "a", "b", NULL);
    Query   *expanded = make_poly_query(BOOLOP_OR, fancy_q, plain_q, NULL);
    return TestQP_new("\"a b", tree, expanded, 3);
}

static TestQueryParser*
leaf_test_escaped_quotes_inside()
{
    Query   *tree     = make_leaf_query(NULL, "\"\\\"a b\\\"\"");
    Query   *plain_q  = make_phrase_query("plain", "\"a", "b\"", NULL);
    Query   *fancy_q  = make_phrase_query("fancy", "a", "b", NULL);
    Query   *expanded = make_poly_query(BOOLOP_OR, fancy_q, plain_q, NULL);
    return TestQP_new("\"\\\"a b\\\"\"", tree, expanded, 3);
}

static TestQueryParser*
leaf_test_escaped_quotes_outside()
{
    Query   *tree = make_leaf_query(NULL, "\\\"a");
    Query   *plain_q  = make_term_query("plain", "\"a");
    Query   *fancy_q  = make_term_query("fancy", "a");
    Query   *expanded = make_poly_query(BOOLOP_OR, fancy_q, plain_q, NULL);
    return TestQP_new("\\\"a", tree, expanded, 4);
}

static TestQueryParser*
leaf_test_single_term_phrase()
{
    Query   *tree     = make_leaf_query(NULL, "\"a\"");
    Query   *plain_q  = make_phrase_query("plain", "a", NULL);
    Query   *fancy_q  = make_phrase_query("fancy", "a", NULL);
    Query   *expanded = make_poly_query(BOOLOP_OR, fancy_q, plain_q, NULL);
    return TestQP_new("\"a\"", tree, expanded, 4);
}

static TestQueryParser*
leaf_test_longer_phrase()
{
    Query   *tree     = make_leaf_query(NULL, "\"a b c\"");
    Query   *plain_q  = make_phrase_query("plain", "a", "b", "c", NULL);
    Query   *fancy_q  = make_phrase_query("fancy", "a", "b", "c", NULL);
    Query   *expanded = make_poly_query(BOOLOP_OR, fancy_q, plain_q, NULL);
    return TestQP_new("\"a b c\"", tree, expanded, 2);
}

static TestQueryParser*
leaf_test_empty_phrase()
{
    Query   *tree     = make_leaf_query(NULL, "\"\"");
    Query   *plain_q  = make_phrase_query("plain", NULL);
    Query   *fancy_q  = make_phrase_query("fancy", NULL);
    Query   *expanded = make_poly_query(BOOLOP_OR, fancy_q, plain_q, NULL);
    return TestQP_new("\"\"", tree, expanded, 0);
}

static TestQueryParser*
leaf_test_phrase_with_stopwords()
{
    Query   *tree     = make_leaf_query(NULL, "\"x a\"");
    Query   *plain_q  = make_phrase_query("plain", "x", "a", NULL);
    Query   *fancy_q  = make_phrase_query("fancy", "a", NULL);
    Query   *expanded = make_poly_query(BOOLOP_OR, fancy_q, plain_q, NULL);
    return TestQP_new("\"x a\"", tree, expanded, 4);
}

static TestQueryParser*
leaf_test_different_tokenization()
{
    Query   *tree     = make_leaf_query(NULL, "a.b");
    Query   *plain_q  = make_term_query("plain", "a.b");
    Query   *fancy_q  = make_phrase_query("fancy", "a", "b", NULL);
    Query   *expanded = make_poly_query(BOOLOP_OR, fancy_q, plain_q, NULL);
    return TestQP_new("a.b", tree, expanded, 3);
}

static TestQueryParser*
leaf_test_http()
{
    char address[] = "http://www.foo.com/bar.html";
    Query *tree = make_leaf_query(NULL, address);
    Query *plain_q = make_term_query("plain", address);
    Query *fancy_q = make_phrase_query("fancy", "http", "www", "foo",
        "com", "bar", "html", NULL);
    Query   *expanded = make_poly_query(BOOLOP_OR, fancy_q, plain_q, NULL);
    return TestQP_new(address, tree, expanded, 0);
}

static TestQueryParser*
leaf_test_field()
{
    Query *tree     = make_leaf_query("plain", "b");
    Query *expanded = make_term_query("plain", "b");
    return TestQP_new("plain:b", tree, expanded, 3);
}

static TestQueryParser*
leaf_test_unrecognized_field()
{
    Query *tree     = make_leaf_query("bogusfield", "b");
    Query *expanded = make_term_query("bogusfield", "b");
    return TestQP_new("bogusfield:b", tree, expanded, 0);
}

static TestQueryParser*
leaf_test_unescape_colons()
{
    Query *tree     = make_leaf_query("plain", "a\\:b");
    Query *expanded = make_term_query("plain", "a:b");
    return TestQP_new("plain:a\\:b", tree, expanded, 0);
}

static TestQueryParser*
syntax_test_minus_plus()
{
    Query *leaf = make_leaf_query(NULL, "a");
    Query *tree = make_not_query(leaf);
    return TestQP_new("-+a", tree, NULL, 0);
}

static TestQueryParser*
syntax_test_plus_minus()
{
    // Not a perfect result, but then it's not a good query string. 
    Query *leaf = make_leaf_query(NULL, "a");
    Query *tree = make_not_query(leaf);
    return TestQP_new("+-a", tree, NULL, 0);
}

static TestQueryParser*
syntax_test_minus_minus()
{
    // Not a perfect result, but then it's not a good query string. 
    Query *tree = make_leaf_query(NULL, "a");
    return TestQP_new("--a", tree, NULL, 4);
}

static TestQueryParser*
syntax_test_not_minus()
{
    Query *tree = make_leaf_query(NULL, "a");
    return TestQP_new("NOT -a", tree, NULL, 4);
}

static TestQueryParser*
syntax_test_not_plus()
{
    // Not a perfect result, but then it's not a good query string. 
    Query *leaf = make_leaf_query(NULL, "a");
    Query *tree = make_not_query(leaf);
    return TestQP_new("NOT +a", tree, NULL, 0);
}

static TestQueryParser*
syntax_test_unclosed_parens()
{
    // Not a perfect result, but then it's not a good query string. 
    Query *inner = make_poly_query(BOOLOP_OR, NULL);
    Query *tree = make_poly_query(BOOLOP_OR, inner, NULL);
    return TestQP_new("((", tree, NULL, 0);
}

static TestQueryParser*
syntax_test_escaped_quotes_outside()
{
    Query *tree = make_leaf_query(NULL, "\\\"a\\\"");
    return TestQP_new("\\\"a\\\"", tree, NULL, 4);
}

static TestQueryParser*
syntax_test_escaped_quotes_inside()
{
    Query *tree = make_leaf_query(NULL, "\"\\\"a\\\"\"");
    return TestQP_new("\"\\\"a\\\"\"", tree, NULL, 4);
}

/***************************************************************************/

typedef TestQueryParser*
(*kino_TestQPSyntax_test_t)();

static kino_TestQPSyntax_test_t leaf_test_funcs[] = {
    leaf_test_simple_term,
    leaf_test_simple_phrase,
    leaf_test_unclosed_quote,
    leaf_test_escaped_quotes_inside,
    leaf_test_escaped_quotes_outside,
    leaf_test_single_term_phrase,
    leaf_test_longer_phrase,
    leaf_test_empty_phrase,
    leaf_test_different_tokenization,
    leaf_test_phrase_with_stopwords,
    leaf_test_http,
    leaf_test_field,
    leaf_test_unrecognized_field,
    leaf_test_unescape_colons,
    NULL
};

static kino_TestQPSyntax_test_t syntax_test_funcs[] = {
    syntax_test_minus_plus,
    syntax_test_plus_minus,
    syntax_test_minus_minus,
    syntax_test_not_minus,
    syntax_test_not_plus,
    syntax_test_unclosed_parens,
    syntax_test_escaped_quotes_outside,
    syntax_test_escaped_quotes_inside,
    NULL
};

void
TestQPSyntax_run_tests(Folder *index)
{
    uint32_t i;
    TestBatch     *batch      = TestBatch_new(58);
    IndexSearcher *searcher   = IxSearcher_new((Obj*)index);
    QueryParser   *qparser    = QParser_new(IxSearcher_Get_Schema(searcher), 
        NULL, NULL, NULL);
    QParser_Set_Heed_Colons(qparser, true);

    TestBatch_Plan(batch);

    for (i = 0; leaf_test_funcs[i] != NULL; i++) {
        kino_TestQPSyntax_test_t test_func = leaf_test_funcs[i];
        TestQueryParser *test_case = test_func();
        Query *tree     = QParser_Tree(qparser, test_case->query_string);
        Query *expanded = QParser_Expand_Leaf(qparser, test_case->tree);
        Query *parsed   = QParser_Parse(qparser, test_case->query_string);
        Hits  *hits     = IxSearcher_Hits(searcher, (Obj*)parsed, 0, 10, NULL);

        TEST_TRUE(batch, Query_Equals(tree, (Obj*)test_case->tree),
            "tree()    %s", (char*)CB_Get_Ptr8(test_case->query_string));
        TEST_TRUE(batch, Query_Equals(expanded, (Obj*)test_case->expanded),
            "expand_leaf()    %s", (char*)CB_Get_Ptr8(test_case->query_string));
        TEST_INT_EQ(batch, Hits_Total_Hits(hits), test_case->num_hits,
            "hits:    %s", (char*)CB_Get_Ptr8(test_case->query_string));
        DECREF(hits);
        DECREF(parsed);
        DECREF(expanded);
        DECREF(tree);
        DECREF(test_case);
    }

    for (i = 0; syntax_test_funcs[i] != NULL; i++) {
        kino_TestQPSyntax_test_t test_func = syntax_test_funcs[i];
        TestQueryParser *test_case = test_func();
        Query *tree   = QParser_Tree(qparser, test_case->query_string);
        Query *parsed = QParser_Parse(qparser, test_case->query_string);
        Hits  *hits   = IxSearcher_Hits(searcher, (Obj*)parsed, 0, 10, NULL);

        TEST_TRUE(batch, Query_Equals(tree, (Obj*)test_case->tree),
            "tree()    %s", (char*)CB_Get_Ptr8(test_case->query_string));
        TEST_INT_EQ(batch, Hits_Total_Hits(hits), test_case->num_hits,
            "hits:    %s", (char*)CB_Get_Ptr8(test_case->query_string));
        DECREF(hits);
        DECREF(parsed);
        DECREF(tree);
        DECREF(test_case);
    }

    DECREF(batch);
    DECREF(searcher);
    DECREF(qparser);
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

