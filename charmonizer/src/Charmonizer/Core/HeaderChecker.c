#define CHAZ_USE_SHORT_NAMES

#include "Charmonizer/Core/HeaderChecker.h"
#include "Charmonizer/Core/Compiler.h"
#include "Charmonizer/Core/ConfWriter.h"
#include "Charmonizer/Core/Util.h"
#include <string.h>
#include <stdlib.h>

typedef struct Header {
    char        *name;
    chaz_bool_t  exists;
} Header;

/* "hello_world.c" without the hello or the world. */
static char test_code[] = "int main() { return 0; }\n";

/* Keep a sorted, dynamically-sized array of names of all headers we've
 * checked for so far.
 */
static int cache_size          = 0;
static Header **header_cache   = NULL;

/* Comparison function to feed to qsort, bsearch, etc.
 */
static int
S_compare_headers(const void *vptr_a, const void *vptr_b);

/* Run a test compilation and return a new Header object encapsulating the
 * results.
 */
static Header* 
S_discover_header(const char *header_name);

/* Extend the cache, add this Header object to it, and sort.
 */
static void
S_add_to_cache(Header *header);

/* Like add_to_cache, but takes a individual elements instead of a Header* and
 * checks if header exists in array first.
 */
static void
S_maybe_add_to_cache(const char *header_name, chaz_bool_t exists);

void
HeadCheck_init()
{
    Header *null_header = (Header*)malloc(sizeof(Header));

    /* Create terminating record for the dynamic array of Header objects. */
    null_header->name   = NULL;
    null_header->exists = false;
    header_cache = (Header**)malloc(sizeof(void*));
    *header_cache = null_header;
    cache_size = 1;
}

chaz_bool_t
HeadCheck_check_header(const char *header_name)
{
    Header  *header;
    Header   key;
    Header  *fake = &key;
    Header **header_ptr;

    /* Fake up a key to feed to bsearch; see if the header's already there. */
    key.name = (char*)header_name;
    key.exists = false;
    header_ptr = (Header**)bsearch(&fake, header_cache, cache_size, 
        sizeof(void*), S_compare_headers);
    
    /* If it's not there, go try a test compile. */
    if (header_ptr == NULL) {
        header = S_discover_header(header_name);
        S_add_to_cache(header);
    }
    else {
        header = *header_ptr;
    }

    return header->exists;
}

chaz_bool_t
HeadCheck_check_many_headers(const char **header_names)
{
    chaz_bool_t success;
    int i;
    char *code_buf = Util_strdup("");
    size_t needed = sizeof(test_code) + 20;

    /* Build the source code string. */
    for (i = 0; header_names[i] != NULL; i++) {
        needed += strlen(header_names[i]);
        needed += sizeof("#include <>\n");
    }
    code_buf = (char*)malloc(needed);
    code_buf[0] = '\0';
    for (i = 0; header_names[i] != NULL; i++) {
        strcat(code_buf, "#include <");
        strcat(code_buf, header_names[i]);
        strcat(code_buf, ">\n");
    }
    strcat(code_buf, test_code);

    /* If the code compiles, bulk add all header names to the cache. */
    success = CC_test_compile(code_buf, strlen(code_buf));
    if (success) {
        for (i = 0; header_names[i] != NULL; i++) {
            S_maybe_add_to_cache(header_names[i], true);
        }
    }

    free(code_buf);
    return success;
}

static char contains_code[] = 
    QUOTE(  #include <stddef.h>                           )
    QUOTE(  %s                                            )
    QUOTE(  int main() { return offsetof(%s, %s); }       );

chaz_bool_t
HeadCheck_contains_member(const char *struct_name, const char *member,
                               const char *includes)
{
    long needed = sizeof(contains_code) + strlen(struct_name) 
                + strlen(member) + strlen(includes) + 10;
    char *buf = (char*)malloc(needed);
    chaz_bool_t retval;
    sprintf(buf, contains_code, includes, struct_name, member);
    retval = CC_test_compile(buf, strlen(buf));
    free(buf);
    return retval;
}

static int
S_compare_headers(const void *vptr_a, const void *vptr_b) {
    Header **const a = (Header**)vptr_a;
    Header **const b = (Header**)vptr_b;

    /* (NULL is "greater than" any string.) */
    if      ((*a)->name == NULL) { return 1; }
    else if ((*b)->name == NULL) { return -1; }
    else                         { return strcmp((*a)->name, (*b)->name); }
}

static Header* 
S_discover_header(const char *header_name) 
{
    Header* header = (Header*)malloc(sizeof(Header));
    size_t  needed = strlen(header_name) + sizeof(test_code) + 50;
    char *include_test = (char*)malloc(needed); 
    
    /* Assign. */
    header->name = Util_strdup(header_name);

    /* See whether code that tries to pull in this header compiles. */
    sprintf(include_test, "#include <%s>\n%s", header_name, test_code);
    header->exists = CC_test_compile(include_test, strlen(include_test));

    free(include_test);
    return header;
}

static void
S_add_to_cache(Header *header)
{
    /* Realloc array -- inefficient, but this isn't a bottleneck. */
    cache_size++;
    header_cache = (Header**)realloc(header_cache, (cache_size * sizeof(void*)));
    header_cache[ cache_size - 1 ] = header;

    /* Keep the list of headers sorted. */
    qsort(header_cache, cache_size, sizeof(*header_cache), S_compare_headers);
}

static void
S_maybe_add_to_cache(const char *header_name, chaz_bool_t exists)
{
    Header *header;
    Header  key;
    Header *fake = &key;

    /* Fake up a key and bsearch for it. */
    key.name   = (char*)header_name;
    key.exists = exists;
    header = (Header*)bsearch(&fake, header_cache, cache_size, 
        sizeof(void*), S_compare_headers);
    
    /* We've already done the test compile, so skip that step and add it. */
    if (header == NULL) {
        header = (Header*)malloc(sizeof(Header));
        header->name   = Util_strdup(header_name);
        header->exists = exists;
        S_add_to_cache(header);
    }
}

/* Copyright 2006-2011 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

