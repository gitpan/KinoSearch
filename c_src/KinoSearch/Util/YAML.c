#include <string.h>
#include <ctype.h>
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Util/YAML.h"

/* Break up a string at newlines.  Discard blank lines.
 */
static VArray*
split_into_lines(const ByteBuf *input);
    
/* Count the number of leading spaces at the front of the ByteBuf's string. 
 */
static u32_t
calc_indent(ByteBuf *line);

/* Given an array of lines, create a 2-level array, with each array element
 * starting with a line at the lowest level of indentation.
 */
static VArray*
group_by_indent(VArray *lines);

/* Given an array of arrays, with each subarray being a group of lines, build
 * a complex data structure.
 */
static Obj*
build_parse_tree(VArray *groups);

/* Helper for build_parse_tree -- returns a VArray.
 */
static VArray*
build_array(VArray *groups);

/* Helper for build_parse_tree -- returns a Hash.
 */
static Hash*
build_hash(VArray *groups);

/* Attempt to extract a scalar value from an array line.  Return NULL if the
 * attempt fails.
 */
static ByteBuf*
array_line_extract(ByteBuf *line);

/* Extract a scalar hash key from a line.  Attempt to extract a value as well,
 * but store NULL in [val_ptr] if the attempt fails.
 */
static void
hash_line_extract(ByteBuf *line, ByteBuf **key_ptr, Obj **val_ptr);

/* Extract a scalar value, either an identifier delimited by whitespace or an
 * arbitrary value delimited by single quotes.  Fast forward past leading
 * spaces.  Advance [orig_ptr] past consumed character data.
 * 
 * Will return NULL if no scalar can be extracted between [orig_ptr] and
 * [limit], but will raise an error if provided with malformed input.
 */ 
static ByteBuf*
scalar_extract(char **orig_ptr, char **limit);

/* Unescape single quotes, decrementing the length of the ByteBuf as needed.
 */
static void
unescape(ByteBuf *input);

/* Dispatch to either encode_hash or encode_array.
 */
static void
encode_obj(Obj*obj, u32_t indent, ByteBuf *output);

/* Encode a Hash as YAML, descending recursively.
 */
static void
encode_hash(Hash *hash, u32_t indent, ByteBuf *output);

/* Encode a VArray as YAML, descending recursively.
 */
static void
encode_varray(VArray *varray, u32_t indent, ByteBuf *output);

/* Check for invalid scalar input (e.g. newlines), quote and escape if
 * necessary.
 */
static void
encode_scalar(ByteBuf *scalar, ByteBuf *output);

Obj*
YAML_parse_yaml(const ByteBuf *input)
{
    VArray *lines, *groups;
    Obj *output;

    lines = split_into_lines(input);
    if (lines->size == 0) {
        REFCOUNT_DEC(lines);
        return NULL;
    }

    groups = group_by_indent(lines);
    output = build_parse_tree(groups);

    REFCOUNT_DEC(lines);
    REFCOUNT_DEC(groups);

    return output;
}

ByteBuf*
YAML_encode_yaml(kino_Obj *obj) 
{
    ByteBuf *output = NULL;
    
    if (obj != NULL) {
        output = BB_new(0);
        encode_obj(obj, 0, output);
    }

    return output;
}

static VArray*
split_into_lines(const ByteBuf *input) 
{
    char *ptr, *start;
    char *limit = BBEND(input);
    VArray *out_array;
    u32_t linecount = 0;
    bool_t line_has_content = false;
    bool_t line_is_comment  = false;

    /* scan input for newlines to determine max size of out array */
    for (ptr = input->ptr; ptr < limit; ptr++) {
        if (*ptr == '\n')
            linecount++;
    }
    out_array = VA_new(linecount);

    for (ptr = input->ptr, start = input->ptr; ptr < limit; ptr++) {
        /* discard blank lines and comment only lines*/
        if (!isspace(*ptr)) {
            if (!line_has_content) {
                if (*ptr == '#') {
                    line_is_comment = true;
                }
            }
            line_has_content = true;
        }

        if (*ptr == '\n' || ptr == (limit - 1)) {
            if (line_has_content && !line_is_comment) {
                const size_t len = *ptr == '\n'
                    ? ptr - start
                    : ptr - start + 1;
                ByteBuf *line = BB_new_str(start, len);
                VA_Push(out_array, (Obj*)line);
                REFCOUNT_DEC(line);
            }
            start = ptr + 1;
            line_has_content = false;
            line_is_comment  = false;
        }
    }

    return out_array;
}

static u32_t
calc_indent(ByteBuf *input)
{
    char *ptr = input->ptr;
    char *limit = BBEND(input);
    u32_t indent = 0;

    while (ptr < limit && *ptr++ == ' ') { indent++; }

    return indent;
}

static VArray*
group_by_indent(VArray *lines)
{
    VArray *groups = VA_new(0);
    VArray *this_level = VA_new(0);
    u32_t starting_indent = 0;
    u32_t i;

    for (i = 0; i < lines->size; i++) {
        ByteBuf *line = (ByteBuf*)VA_Fetch(lines, i);
        if (this_level->size == 0) {
            starting_indent = calc_indent(line);
        }
        else if (calc_indent(line) == starting_indent) {
            VA_Push(groups, (Obj*)this_level);
            REFCOUNT_DEC(this_level);
            this_level = VA_new(0);
        }
        VA_Push(this_level, (Obj*)line);
    }

    if (this_level->size > 0) {
        VA_Push(groups, (Obj*)this_level);
    }
    REFCOUNT_DEC(this_level);

    return groups;
}


static Obj*
build_parse_tree(VArray *groups)
{
    VArray* first_group = (VArray*)VA_Fetch(groups, 0);
    ByteBuf* first_line = (ByteBuf*)VA_Fetch(first_group, 0);
    char *ptr = first_line->ptr;
    char *limit = BBEND(first_line);

    while (ptr < limit && *ptr == ' ') { ptr++; }

    if (*ptr == '-')
        return (Obj*)build_array(groups);
    else
        return (Obj*)build_hash(groups);
}

static VArray*
build_array(VArray *groups)
{
    VArray *out_array = VA_new(1);
    u32_t i;

    for (i = 0; i < groups->size; i++) {
        VArray *group = (VArray*)VA_Fetch(groups, i);

        /* if only one line, array element is a scalar */
        if (group->size == 1) {
            ByteBuf *line = (ByteBuf*)VA_Fetch(group, 0);
            ByteBuf *value = array_line_extract(line);

            /* don't accept empty values for array elements */
            if (value == NULL)
                CONFESS("Failed to extract array element: %s", line->ptr);

            VA_Push(out_array, (Obj*)value);
            REFCOUNT_DEC(value);
        }
        /* array element is a data structure */
        else {
            VArray *meaningful_lines;
            Obj    *inner_obj;

            /* discard first line */
            ByteBuf* first_line = (ByteBuf*)VA_Shift(group);
            REFCOUNT_DEC(first_line);

            meaningful_lines = group_by_indent(group);
            inner_obj = build_parse_tree(meaningful_lines);
            VA_Push(out_array, inner_obj);
            REFCOUNT_DEC(inner_obj);
            REFCOUNT_DEC(meaningful_lines);
        }
    }

    return out_array;
}

static Hash*
build_hash(VArray *groups)
{
    Hash *out_hash = Hash_new(16);
    u32_t i;

    for (i = 0; i < groups->size; i++) {
        VArray *group = (VArray*)VA_Fetch(groups, i);
        ByteBuf *first_line = (ByteBuf*)VA_Fetch(group, 0);
        ByteBuf *key = NULL;
        Obj     *val = NULL;

        /* attempt to extract a key value pair from the line */
        hash_line_extract(first_line, &key, &val);

        /* maybe the value is a complex data structure */
        if (val == NULL) {
            VArray *val_group, *sub_groups;
            u32_t j;

            if (group->size == 1) {
                CONFESS("Failed to extract hash value for %s", key->ptr);
            }
            val_group = VA_new(group->size - 1);

            /* copy all lines in the group except the first (the key) */
            for (j = 1; j < group->size; j++) {
                Obj *elem = VA_Fetch(group, j);
                Obj *copy = Obj_Clone(elem);
                VA_Push(val_group, copy);
                REFCOUNT_DEC(copy);
            }

            /* recurse */
            sub_groups = group_by_indent(val_group);
            val = build_parse_tree(sub_groups);

            REFCOUNT_DEC(sub_groups);
            REFCOUNT_DEC(val_group);
        }

        Hash_Store_BB(out_hash, key, val);
        REFCOUNT_DEC(key);
        REFCOUNT_DEC(val);
    }
    
    return out_hash;
}

static ByteBuf*
array_line_extract(ByteBuf *line)
{
    char *ptr   = line->ptr;
    char *limit = BBEND(line);

    /* scoot past leading whitespace and "- " */
    while (ptr < limit && *ptr == ' ') { ptr++; }
    if (ptr > (limit - 2) || strncmp(ptr, "- ", 2) != 0)
        return NULL;
    ptr += 2;

    return scalar_extract(&ptr, &limit);
}
static void
hash_line_extract(ByteBuf *line, ByteBuf **key_ptr, Obj **val_ptr)
{
    char *ptr   = line->ptr;
    char *limit = BBEND(line);

    /* extract key */
    *key_ptr = scalar_extract(&ptr, &limit);
    if (*key_ptr == NULL) {
        CONFESS("failed to extract key from %s", line->ptr);
    }
    while (*ptr == ' ' && ptr < (limit - 1)) { ptr++; }
    if (*ptr != ':')
        CONFESS("Malformed hash key line: %s", line->ptr);
    if (ptr == limit - 1)
        ptr += 1;
    else if (!isspace(*(ptr + 1)))
        CONFESS("Malformed hash key line: %s", line->ptr);
    else 
        ptr += 2;

    /* attempt to extract value (failure is ok) */
    *val_ptr = (Obj*)scalar_extract(&ptr, &limit);
}

ByteBuf*
scalar_extract(char **orig_ptr, char **limit_ptr) 
{
    char *ptr   = *orig_ptr;
    char *limit = *limit_ptr;
    char *start = ptr;
    ByteBuf *retval = NULL;

    /* blow past whitespace */
    while (ptr < limit && *ptr == ' ') { ptr++, start++; }

    /* blank */
    if (ptr == limit)
        ;
    /* if the value is single-quote delimited */
    else if (ptr + 1 < limit && *ptr == '\'') {
        /* don't include the opening quote */
        start++, ptr++;

        /* find the end, minus the closing quote */
        for ( ; ; ptr++) {
            if (ptr == limit)
                CONFESS("Malformed quotes: '%s'", *orig_ptr);

            if (*ptr == '\'') {
                if (ptr < (limit - 1) && *(ptr + 1) == '\'') {
                    /* advance past escaped single quote */
                    ptr += 1;
                }
                else {
                    /* bail out, we've found the closing quote */
                    break;
                }
            }
        }
        *orig_ptr = ptr + 1;
        retval = BB_new_str(start, (ptr - start));
        unescape(retval);
    }
    /*  if the value is space-delimited */
    else if (ptr < limit) {
        while (ptr < limit && !isspace(*ptr) && *ptr != ':') { ptr++; }
        *orig_ptr = ptr;
        retval = BB_new_str(start, ptr - start);
    }
    /* comment */
    else if (*ptr == '#') {
        return NULL;
    }
    else if (ptr < limit) {
        CONFESS("Illegal scalar value: %s", *orig_ptr);
    }

    return retval;
}

static void
unescape(ByteBuf *input) 
{
    char *source = input->ptr;
    char *dest   = source;
    char *const limit = BBEND(input);

    while (source < limit) {
        if (*source == '\'') {
            if (source < (limit - 1) && *(source + 1) == '\'')
                source++;
        }
        *dest++ = *source++;
    }
    input->len = dest - input->ptr;
    input->ptr[ input->len ] = '\0';
}

static void
encode_obj(Obj*obj, u32_t indent, ByteBuf *output)
{
    if (OBJ_IS_A(obj, HASH)) {
        encode_hash((Hash*)obj, indent, output);
    }
    else if (OBJ_IS_A(obj, VARRAY)) {
        encode_varray((VArray*)obj, indent, output);
    }
    else {
        CONFESS("Object is neither Hash nor VArray: %s", obj->_->class_name);
    }
}

static void
append_spaces(ByteBuf *output, u32_t num_spaces)
{
    BB_GROW(output, output->len + num_spaces);
    memset(BBEND(output), ' ', num_spaces);
    output->len += num_spaces;
    *BBEND(output) = '\0';
}

static void
encode_hash(Hash *hash, u32_t indent, ByteBuf *output)
{
    kino_ByteBuf *key;
    kino_Obj     *val;

    /* ballpark extra space to minimize reallocations */
    BB_GROW(output, output->len + (hash->size * (indent + 5)));

    Hash_Iter_Init(hash);
    while (Hash_Iter_Next(hash, &key, &val)) {
        /* append the key to the output */
        BB_GROW(output, output->len + indent + key->len + 20);
        append_spaces(output, indent);
        encode_scalar(key, output);
        BB_Cat_Str(output, ": ", 2);

        if (OBJ_IS_A(val, BYTEBUF)) {
            encode_scalar((ByteBuf*)val, output);
            BB_Cat_Str(output, "\n", 1);
        }
        else {
            BB_Cat_Str(output, "\n", 1);
            encode_obj(val, indent + 2, output);
        }
    }
}

static void
encode_scalar(ByteBuf *scalar, ByteBuf *output)
{
    char *start = scalar->ptr;
    char *limit = BBEND(scalar);
    char *source;
    size_t space = 0;
    bool_t needs_quoting = false;

    /* chop whitespace from both ends */
    for ( ; limit > start; limit--) {
        if (!isspace(*(limit - 1)))
            break;
    }
    for ( ; start < limit; start++) {
        if (!isspace(*start))
            break;
    }

    /* validate input, see if quotes are required */
    for (source = start; source < limit; source++) {
        if (!isprint(*source))
            CONFESS("invalid character: %d", *source);

        switch (*source) {
        case '\r':
        case '\n':
        case '\t': 
            CONFESS("tab or return character in input: %s", scalar->ptr);
            break;
        
        case '\'':
            space++;
            /* fall through */
        case ':':
        case ' ':
            needs_quoting = true;
            space++;
            break;

        default:
            space++;
            break;
        }
    }

    /* quote empty strings */
    if (space == 0)
        needs_quoting = true;

    BB_GROW(output, output->len + space + 3);
    if (needs_quoting) {
        char *dest = BBEND(output);
        space += 2;

        *dest++ = '\'';
        for (source = start; source < limit; source++) {
            if (*source == '\'')
                *dest++ = '\'';
            *dest++ = *source;
        }
        *dest++ = '\'';
    }
    else {
        memcpy(BBEND(output), start, space);
    }
    output->len += space;
    output->ptr[ output->len ] = '\0';
}

static void
encode_varray(VArray *varray, u32_t indent, ByteBuf *output)
{
    u32_t i;

    /* ballpark space */
    BB_GROW(output, output->len + (varray->size * (indent + 5)));

    for (i = 0; i < varray->size; i++) {
        kino_Obj *elem = VA_Fetch(varray, i);

        BB_GROW(output, output->len + indent + 5);
        append_spaces(output, indent);
        BB_Cat_Str(output, "- ", 2);

        if (elem == NULL) {
            CONFESS("missing element in varray");
        }
        else if (OBJ_IS_A(elem, BYTEBUF)) {
            encode_scalar((ByteBuf*)elem, output);
            BB_Cat_Str(output, "\n", 1);
        }
        else {
            BB_Cat_Str(output, "\n", 1);
            encode_obj(elem, indent + 2, output);
        }
    }
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

