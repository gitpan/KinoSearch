#define C_KINO_CHARBUF
#define C_KINO_VIEWCHARBUF
#define C_KINO_ZOMBIECHARBUF
#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

#include "KinoSearch/Object/VTable.h"
#include "KinoSearch/Object/CharBuf.h"

#include "KinoSearch/Object/Err.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/Memory.h"
#include "KinoSearch/Util/StringHelper.h"

// Helper function for throwing invalid UTF-8 error. Since THROW uses
// a CharBuf internally, calling THROW with invalid UTF-8 would create an
// infinite loop -- so we fwrite some of the bogus text to stderr invoke
// THROW with a generic message.
static void
S_die_invalid_utf8(const char *text, size_t size);

// Helper function for throwing invalid pattern error. 
static void
S_die_invalid_pattern(const char *pattern);

ZombieCharBuf EMPTY = { ZOMBIECHARBUF, {1}, "", 0, 0 };

CharBuf*
CB_new(size_t size) 
{
    CharBuf *self = (CharBuf*)VTable_Make_Obj(CHARBUF);
    return CB_init(self, size);
}

CharBuf*
CB_init(CharBuf *self, size_t size) 
{
    // Derive. 
    self->ptr = (char*)MALLOCATE(size + 1);

     // Init. 
    *self->ptr = '\0'; // Empty string. 
 
    // Assign. 
    self->size   = 0;
    self->cap    = size + 1;

    return self;
}

CharBuf*
CB_new_from_utf8(const char *ptr, size_t size) 
{
    if (!StrHelp_utf8_valid(ptr, size))
        S_die_invalid_utf8(ptr, size);
    return CB_new_from_trusted_utf8(ptr, size);
}

CharBuf*
CB_new_from_trusted_utf8(const char *ptr, size_t size) 
{
    CharBuf *self = (CharBuf*)VTable_Make_Obj(CHARBUF);

    // Derive. 
    self->ptr = (char*)MALLOCATE(size + 1);

    // Copy. 
    memcpy(self->ptr, ptr, size);

    // Assign. 
    self->size      = size;
    self->cap       = size + 1; 
    self->ptr[size] = '\0'; // Null terminate. 
    
    return self;
}

CharBuf*
CB_new_steal_from_trusted_str(char *ptr, size_t size, size_t cap) 
{
    CharBuf *self = (CharBuf*)VTable_Make_Obj(CHARBUF);
    self->ptr  = ptr;
    self->size = size;
    self->cap  = cap;
    return self;
}

CharBuf*
CB_new_steal_str(char *ptr, size_t size, size_t cap) 
{
    StrHelp_utf8_valid(ptr, size);
    return CB_new_steal_from_trusted_str(ptr, size, cap);
}

CharBuf*
CB_newf(const char *pattern, ...) {
    CharBuf *self = CB_new(strlen(pattern));
    va_list args;
    va_start(args, pattern);
    CB_VCatF(self, pattern, args);
    va_end(args);
    return self;
}

void
CB_destroy(CharBuf *self)
{
    FREEMEM(self->ptr);
    SUPER_DESTROY(self, CHARBUF);
}

int32_t
CB_hash_sum(CharBuf *self)
{
    uint32_t hashvalue = 5381; 
    ZombieCharBuf *iterator = ZCB_WRAP(self);
    
    {
        const CB_nip_one_t nip_one 
            = (CB_nip_one_t)METHOD(iterator->vtable, CB, Nip_One);
        while (iterator->size) {
            uint32_t code_point = (uint32_t)nip_one((CharBuf*)iterator);
            hashvalue = ((hashvalue << 5) + hashvalue) ^ code_point; 
        } 
    }

    return (int32_t) hashvalue;
}

static void
S_grow(CharBuf *self, size_t size)
{
    if (size >= self->cap) { 
        CB_Grow(self, size);
    }
}

char*
CB_grow(CharBuf *self, size_t size) 
{
    if (size >= self->cap) { 
        self->cap = size + 1;
        self->ptr = (char*)REALLOCATE(self->ptr, self->cap);
    }
    return self->ptr;
}

static void
S_die_invalid_utf8(const char *text, size_t size)
{
    fprintf(stderr, "Invalid UTF-8, aborting: '");
    fwrite(text, sizeof(char), size < 200 ? size : 200, stderr);
    if (size > 200) fwrite("[...]", sizeof(char), 5, stderr);
    fprintf(stderr, "'\n");
    THROW(ERR, "Invalid UTF-8.");
}

static void
S_die_invalid_pattern(const char *pattern)
{
    size_t  pattern_len = strlen(pattern);
    fprintf(stderr, "Invalid pattern, aborting: '");
    fwrite(pattern, sizeof(char), pattern_len, stderr);
    fprintf(stderr, "'\n");
    THROW(ERR, "Invalid pattern.");
}

void
CB_setf(CharBuf *self, const char *pattern, ...)
{
    va_list args;
    CB_Set_Size(self, 0);
    va_start(args, pattern);
    CB_VCatF(self, pattern, args);
    va_end(args);
}

void
CB_catf(CharBuf *self, const char *pattern, ...)
{
    va_list args;
    va_start(args, pattern);
    CB_VCatF(self, pattern, args);
    va_end(args);
}

void
CB_vcatf(CharBuf *self, const char *pattern, va_list args)
{
    size_t      pattern_len   = strlen(pattern);
    const char *pattern_start = pattern;
    const char *pattern_end   = pattern + pattern_len;
    char        buf[64];

    for ( ; pattern < pattern_end; pattern++) {
        const char *slice_end = pattern;

        // Consume all characters leading up to a '%'. 
        while (slice_end < pattern_end && *slice_end != '%') { slice_end++; }
        if (pattern != slice_end) {
            size_t size = slice_end - pattern;
            CB_Cat_Trusted_Str(self, pattern, size);
            pattern = slice_end;
        }

        if (pattern < pattern_end) {
            pattern++; // Move past '%'. 

            switch (*pattern) {
                case '%': {
                    CB_Cat_Trusted_Str(self, "%", 1);
                } 
                break;

                case 'o': {
                    Obj *obj = va_arg(args, Obj*);
                    if (!obj) {
                        CB_Cat_Trusted_Str(self, "[NULL]", 6);
                    }
                    else if (Obj_Is_A(obj, CHARBUF)) {
                        CB_Cat(self, (CharBuf*)obj);
                    }
                    else {
                        CharBuf *string = Obj_To_String(obj);
                        CB_Cat(self, string);
                        DECREF(string);
                    }
                } 
                break;

                case 'i': {
                    int64_t val = 0;
                    size_t size;

                    if (pattern[1] == '8') {
                        val = va_arg(args, int32_t);
                        pattern++;
                    }
                    else if (pattern[1] == '3' && pattern[2] == '2') {
                        val = va_arg(args, int32_t);
                        pattern += 2;
                    }
                    else if (pattern[1] == '6' && pattern[2] == '4') {
                        val = va_arg(args, int64_t);
                        pattern += 2;
                    }
                    else {
                        S_die_invalid_pattern(pattern_start);
                    }
                    size = sprintf(buf, "%" I64P, val);
                    CB_Cat_Trusted_Str(self, buf, size);
                } 
                break;

                case 'u': {
                    uint64_t val = 0;
                    size_t size;

                    if (pattern[1] == '8') {
                        val = va_arg(args, uint32_t);
                        pattern += 1;
                    }
                    else if (pattern[1] == '3' && pattern[2] == '2') {
                        val = va_arg(args, uint32_t);
                        pattern += 2;
                    }
                    else if (pattern[1] == '6' && pattern[2] == '4') {
                        val = va_arg(args, uint64_t);
                        pattern += 2;
                    }
                    else {
                        S_die_invalid_pattern(pattern_start);
                    }
                    size = sprintf(buf, "%" U64P, val);
                    CB_Cat_Trusted_Str(self, buf, size);
                } 
                break;

                case 'f': {
                    if (pattern[1] == '6' && pattern[2] == '4') {
                        double num  = va_arg(args, double);
                        char bigbuf[512];
                        size_t size = sprintf(bigbuf, "%g", num);
                        CB_Cat_Trusted_Str(self, bigbuf, size);
                        pattern += 2;
                    }
                    else {
                        S_die_invalid_pattern(pattern_start);
                    }
                } 
                break;

                case 'x': {
                    if (pattern[1] == '3' && pattern[2] == '2') {
                        unsigned long val = va_arg(args, uint32_t);
                        size_t size = sprintf(buf, "%.8lx", val);
                        CB_Cat_Trusted_Str(self, buf, size);
                        pattern += 2;
                    }
                    else {
                        S_die_invalid_pattern(pattern_start);
                    }
                } 
                break;

                case 's': {
                    char *string = va_arg(args, char*);
                    if (string == NULL) {
                        CB_Cat_Trusted_Str(self, "[NULL]", 6);
                    }
                    else {
                        size_t size = strlen(string);
                        if (StrHelp_utf8_valid(string, size)) {
                            CB_Cat_Trusted_Str(self, string, size);
                        }
                        else {
                            CB_Cat_Trusted_Str(self, "[INVALID UTF8]", 14);
                        }
                    }
                } 
                break;

                // Assume NULL-terminated pattern string, which eliminates the
                // need for bounds checking if '%' is the last visible
                // character.
                default: {
                    S_die_invalid_pattern(pattern_start);
                }
            }
        }
    }
}

CharBuf*
CB_to_string(CharBuf *self)
{
    return CB_new_from_trusted_utf8(self->ptr, self->size);
}

void
CB_cat_char(CharBuf *self, uint32_t code_point)
{
    const size_t MAX_UTF8_BYTES = 4;
    if (self->size + MAX_UTF8_BYTES >= self->cap) { 
        S_grow(self, Memory_oversize(self->size + MAX_UTF8_BYTES, 
            sizeof(char)));
    }
    char *end = self->ptr + self->size;
    size_t count = StrHelp_encode_utf8_char(code_point, (uint8_t*)end);
    self->size += count;
    *(end + count) = '\0';
}

int32_t
CB_swap_chars(CharBuf *self, uint32_t match, uint32_t replacement)
{
    int32_t num_swapped = 0;

    if (match > 127) { 
        THROW(ERR, "match point too high: %u32", match);
    }
    else if (replacement > 127) { 
        THROW(ERR, "replacement code point too high: %u32", replacement);
    }
    else {
        char *ptr = self->ptr;
        char *const limit = ptr + self->size;
        for ( ; ptr < limit; ptr++) {
            if (*ptr == (char)match) { 
                *ptr = (char)replacement; 
                num_swapped++;
            }
        }
    }

    return num_swapped;
}

int64_t
CB_to_i64(CharBuf *self) 
{
    return CB_BaseX_To_I64(self, 10);
}

int64_t
CB_basex_to_i64(CharBuf *self, uint32_t base)
{
    ZombieCharBuf *iterator = ZCB_WRAP(self);
    int64_t retval = 0;
    bool_t is_negative = false;

    // Advance past minus sign. 
    if (ZCB_Code_Point_At(iterator, 0) == '-') { 
        ZCB_Nip_One(iterator);
        is_negative = true;
    }

    // Accumulate. 
    while (iterator->size) {
        int32_t code_point = ZCB_Nip_One(iterator);
        if (isalnum(code_point)) {
            int32_t addend = isdigit(code_point)
                           ? code_point - '0'
                           : tolower(code_point) - 'a' + 10;
            if (addend > (int32_t)base) break;
            retval *= base;
            retval += addend;
        }
        else {
            break;
        }
    }

    // Apply minus sign. 
    if (is_negative) retval = 0 - retval;

    return retval;
}

double
CB_to_f64(CharBuf *self)
{
    return strtod(self->ptr, NULL);
}

CharBuf*
CB_to_cb8(CharBuf *self)
{
    return CB_new_from_trusted_utf8(self->ptr, self->size);
}

CharBuf*
CB_clone(CharBuf *self) 
{
    return CB_new_from_trusted_utf8(self->ptr, self->size);
}

CharBuf*
CB_load(CharBuf *self, Obj *dump)
{
    CharBuf *source = (CharBuf*)CERTIFY(dump, CHARBUF);
    UNUSED_VAR(self);
    return CB_Clone(source);
}

void
CB_serialize(CharBuf *self, OutStream *target)
{
    OutStream_Write_C32(target, self->size);
    OutStream_Write_Bytes(target, self->ptr, self->size);
}

CharBuf*
CB_deserialize(CharBuf *self, InStream *instream)
{
    size_t size = InStream_Read_C32(instream);
    self = self ? self : (CharBuf*)VTable_Make_Obj(CHARBUF);
    if (size >= self->cap) { S_grow(self, size); }
    InStream_Read_Bytes(instream, self->ptr, size);
    self->size = size;
    self->ptr[size] = '\0';
    if (!StrHelp_utf8_valid(self->ptr, size)) {
        S_die_invalid_utf8(self->ptr, size);
    }
    return self;
}

void
CB_mimic_str(CharBuf *self, const char* ptr, size_t size) 
{
    if (!StrHelp_utf8_valid(ptr, size)) {
        S_die_invalid_utf8(ptr, size);
    }
    if (size >= self->cap) { S_grow(self, size); }
    memmove(self->ptr, ptr, size);
    self->size = size;
    self->ptr[size] = '\0';
}

void
CB_mimic(CharBuf *self, Obj *other)
{
    CharBuf *evil_twin = (CharBuf*)CERTIFY(other, CHARBUF);
    if (evil_twin->size >= self->cap) { S_grow(self, evil_twin->size); }
    memmove(self->ptr, evil_twin->ptr, evil_twin->size);
    self->size = evil_twin->size;
    self->ptr[evil_twin->size] = '\0';
}

void 
CB_cat_str(CharBuf *self, const char* ptr, size_t size) 
{
    if (!StrHelp_utf8_valid(ptr, size))
        S_die_invalid_utf8(ptr, size);
    CB_cat_trusted_str(self, ptr, size);
}

void 
CB_cat_trusted_str(CharBuf *self, const char* ptr, size_t size) 
{
    const size_t new_size = self->size + size;
    if (new_size >= self->cap) { 
        size_t amount = Memory_oversize(new_size, sizeof(char));
        S_grow(self, amount); 
    }
    memcpy((self->ptr + self->size), ptr, size);
    self->size = new_size;
    self->ptr[new_size] = '\0';
}

void
CB_cat(CharBuf *self, const CharBuf *other) 
{
    const size_t new_size = self->size + other->size;
    if (new_size >= self->cap) { 
        size_t amount = Memory_oversize(new_size, sizeof(char));
        S_grow(self, amount); 
    }
    memcpy((self->ptr + self->size), other->ptr, other->size);
    self->size = new_size;
    self->ptr[new_size] = '\0';
}

bool_t
CB_starts_with(CharBuf *self, const CharBuf *prefix)
{
    return CB_starts_with_str(self, prefix->ptr, prefix->size);
}

bool_t
CB_starts_with_str(CharBuf *self, const char *prefix, size_t size)
{
    if (     size <= self->size
        &&  (memcmp(self->ptr, prefix, size) == 0)
    ) {
        return true;
    }
    else {
        return false;
    }
}

bool_t
CB_equals(CharBuf *self, Obj *other)
{
    CharBuf *const evil_twin = (CharBuf*)other;
    if (evil_twin == self) return true;
    if (!Obj_Is_A(other, CHARBUF)) return false;
    return CB_equals_str(self, evil_twin->ptr, evil_twin->size);
}

int32_t
CB_compare_to(CharBuf *self, Obj *other)
{
    CERTIFY(other, CHARBUF);
    return CB_compare(&self, &other);
}

bool_t
CB_equals_str(CharBuf *self, const char *ptr, size_t size)
{
    if (self->size != size)
        return false;
    return (memcmp(self->ptr, ptr, self->size) == 0);
}

bool_t
CB_ends_with(CharBuf *self, const CharBuf *postfix)
{
    return CB_ends_with_str(self, postfix->ptr, postfix->size);
}

bool_t
CB_ends_with_str(CharBuf *self, const char *postfix, size_t postfix_len)
{
    if (postfix_len <= self->size) { 
        char *start = self->ptr + self->size - postfix_len;
        if (memcmp(start, postfix, postfix_len) == 0)
            return true;
    }

    return false;
}

uint32_t
CB_trim(CharBuf *self)
{
    return CB_Trim_Top(self) + CB_Trim_Tail(self);
}

uint32_t
CB_trim_top(CharBuf *self)
{
    char     *ptr   = self->ptr;
    char     *end   = ptr + self->size;
    uint32_t  count = 0;

    while (ptr < end) {
        uint32_t code_point = StrHelp_decode_utf8_char(ptr);
        if (!StrHelp_is_whitespace(code_point)) break;
        ptr += StrHelp_UTF8_COUNT[*(uint8_t*)ptr];
        count++;
    }

    if (count) {
        // Copy string backwards. 
        self->size = end - ptr;
        memmove(self->ptr, ptr, self->size);
    }

    return count;
}

uint32_t
CB_trim_tail(CharBuf *self)
{
    uint32_t      count    = 0;
    char *const   top      = self->ptr; 
    const char   *ptr      = top + self->size;
    size_t        new_size = self->size;

    while (NULL != (ptr = StrHelp_back_utf8_char(ptr, top))) {
        uint32_t code_point = StrHelp_decode_utf8_char(ptr);
        if (!StrHelp_is_whitespace(code_point)) break;
        new_size = ptr - top;
        count++;
    }
    self->size = new_size;

    return count;
}

size_t
CB_nip(CharBuf *self, size_t count)
{
    size_t       num_nipped = 0;
    char        *ptr        = self->ptr;
    char *const  end        = ptr + self->size;
    for ( ; ptr < end  && count--; ptr += StrHelp_UTF8_COUNT[*(uint8_t*)ptr]) {
        num_nipped++;
    }
    self->size = end - ptr;
    memmove(self->ptr, ptr, self->size);
    return num_nipped;
}

int32_t
CB_nip_one(CharBuf *self)
{
    if (self->size == 0) {
        return 0;
    }
    else {
        int32_t retval = (int32_t)StrHelp_decode_utf8_char(self->ptr);
        size_t consumed = StrHelp_UTF8_COUNT[*(uint8_t*)self->ptr];
        char *ptr = self->ptr + StrHelp_UTF8_COUNT[*(uint8_t*)self->ptr];
        self->size -= consumed;
        memmove(self->ptr, ptr, self->size);
        return retval;
    }
}

size_t
CB_chop(CharBuf *self, size_t count)
{
    size_t      num_chopped = 0;
    char       *top         = self->ptr;
    const char *ptr         = top + self->size;
    for (num_chopped = 0; num_chopped < count; num_chopped++) {
        const char *end = ptr;
        if (NULL == (ptr = StrHelp_back_utf8_char(ptr, top))) break;
        self->size -= (end - ptr);
    }
    return num_chopped;
}

size_t
CB_length(CharBuf *self)
{
    size_t  len  = 0;
    char   *ptr  = self->ptr; 
    char   *end  = ptr + self->size;
    while (ptr < end) {
        ptr += StrHelp_UTF8_COUNT[*(uint8_t*)ptr];
        len++;
    }
    return len;
}

size_t
CB_truncate(CharBuf *self, size_t count)
{
    uint32_t num_code_points;
    ZombieCharBuf *iterator = ZCB_WRAP(self);
    num_code_points = ZCB_Nip(iterator, count);
    self->size -= iterator->size;
    return num_code_points;
}

uint32_t
CB_code_point_at(CharBuf *self, size_t tick)
{
    size_t count = 0;
    char *ptr = self->ptr;
    char *const end = ptr + self->size;

    for ( ; ptr < end; ptr += StrHelp_UTF8_COUNT[*(uint8_t*)ptr]) {
        if (count == tick) return StrHelp_decode_utf8_char(ptr);
        count++;
    }

    return 0;
}

uint32_t
CB_code_point_from(CharBuf *self, size_t tick)
{
    size_t      count = 0;
    char       *top   = self->ptr;
    const char *ptr   = top + self->size;

    for (count = 0; count < tick; count++) {
        if (NULL == (ptr = StrHelp_back_utf8_char(ptr, top))) return 0;
    }
    return StrHelp_decode_utf8_char(ptr);
}

CharBuf*
CB_substring(CharBuf *self, size_t offset, size_t len)
{
    ZombieCharBuf *iterator = ZCB_WRAP(self);
    char *sub_start;
    size_t byte_len;

    ZCB_Nip(iterator, offset);
    sub_start = iterator->ptr;
    ZCB_Nip(iterator, len);
    byte_len = iterator->ptr - sub_start;

    return CB_new_from_trusted_utf8(sub_start, byte_len);
}

int 
CB_compare(const void *va, const void *vb) 
{
    const CharBuf *a = *(const CharBuf**)va;
    const CharBuf *b = *(const CharBuf**)vb;
    ZombieCharBuf *iterator_a = ZCB_WRAP(a);
    ZombieCharBuf *iterator_b = ZCB_WRAP(b);
    while (iterator_a->size && iterator_b->size) {
        int32_t code_point_a = ZCB_Nip_One(iterator_a);
        int32_t code_point_b = ZCB_Nip_One(iterator_b);
        const int32_t comparison = code_point_a - code_point_b;
        if (comparison != 0) return comparison;
    }
    if (iterator_a->size != iterator_b->size) {
        return iterator_a->size < iterator_b->size ? -1 : 1;
    }
    return 0;
}

bool_t
CB_less_than(const void *va, const void *vb)
{
    return CB_compare(va, vb) < 0 ? 1 : 0;
}

void
CB_set_size(CharBuf *self, size_t size) { self->size = size;  }
size_t
CB_get_size(CharBuf *self)              { return self->size; }
uint8_t*
CB_get_ptr8(CharBuf *self)              { return (uint8_t*)self->ptr; }

/*****************************************************************/

ViewCharBuf*
ViewCB_new_from_utf8(const char *utf8, size_t size)
{
    if (!StrHelp_utf8_valid(utf8, size))
        S_die_invalid_utf8(utf8, size);
    return ViewCB_new_from_trusted_utf8(utf8, size);
}

ViewCharBuf*
ViewCB_new_from_trusted_utf8(const char *utf8, size_t size)
{
    ViewCharBuf *self = (ViewCharBuf*)VTable_Make_Obj(VIEWCHARBUF);
    return ViewCB_init(self, utf8, size);
}

ViewCharBuf*
ViewCB_init(ViewCharBuf *self, const char *utf8, size_t size)
{
    self->ptr  = (char*)utf8;
    self->size = size;
    self->cap  = 0;
    return self;
}

void
ViewCB_destroy(ViewCharBuf *self)
{
    // Note that we do not free self->ptr, and that we invoke the
    // SUPER_DESTROY with CHARBUF instead of VIEWCHARBUF.
    SUPER_DESTROY(self, CHARBUF);
}

void
ViewCB_assign(ViewCharBuf *self, const CharBuf *other)
{
    self->ptr  = other->ptr;
    self->size = other->size;
}

void
ViewCB_assign_str(ViewCharBuf *self, const char *utf8, size_t size)
{
    if (!StrHelp_utf8_valid(utf8, size))
        S_die_invalid_utf8(utf8, size);
    self->ptr  = (char*)utf8;
    self->size = size;
}

uint32_t
ViewCB_trim_top(ViewCharBuf *self)
{
    uint32_t  count = 0;
    char     *ptr   = self->ptr;
    char     *end   = ptr + self->size;

    while (ptr < end) {
        uint32_t code_point = StrHelp_decode_utf8_char(ptr);
        if (!StrHelp_is_whitespace(code_point)) break;
        ptr += StrHelp_UTF8_COUNT[*(uint8_t*)ptr];
        count++;
    }

    if (count) {
        self->size = end - ptr;
        self->ptr  = ptr;
    }

    return count;
}

size_t
ViewCB_nip(ViewCharBuf *self, size_t count)
{
    size_t  num_nipped;
    char   *ptr    = self->ptr; 
    char   *end    = ptr + self->size;
    for (num_nipped = 0; 
         ptr < end && count--; 
         ptr += StrHelp_UTF8_COUNT[*(uint8_t*)ptr]
    ) {
        num_nipped++;
    }
    self->size = end - ptr;
    self->ptr  = ptr;
    return num_nipped;
}

int32_t
ViewCB_nip_one(ViewCharBuf *self)
{
    if (self->size == 0) {
        return 0;
    }
    else {
        int32_t retval = (int32_t)StrHelp_decode_utf8_char(self->ptr);
        size_t consumed = StrHelp_UTF8_COUNT[*(uint8_t*)self->ptr];
        self->ptr  += consumed;
        self->size -= consumed;
        return retval;
    }
}

char*
ViewCB_grow(ViewCharBuf *self, size_t size)
{
    UNUSED_VAR(size);
    THROW(ERR, "Can't grow a ViewCharBuf ('%o')", self);
    UNREACHABLE_RETURN(char*);
}

/*****************************************************************/

ZombieCharBuf*
ZCB_new(void *allocation)
{
    static char empty_string[] = "";
    ZombieCharBuf *self = (ZombieCharBuf*)allocation;
    self->ref.count    = 1;
    self->vtable       = ZOMBIECHARBUF;
    self->cap          = 0;
    self->size         = 0;
    self->ptr          = empty_string;
    return self;
}

ZombieCharBuf*
ZCB_newf(void *allocation, size_t alloc_size, const char *pattern, ...)
{
    ZombieCharBuf *self = (ZombieCharBuf*)allocation;

    self->ref.count    = 1;
    self->vtable       = ZOMBIECHARBUF;
    self->cap          = alloc_size - sizeof(ZombieCharBuf);
    self->size         = 0;
    self->ptr          = ((char*)allocation) + sizeof(ZombieCharBuf);

    va_list args;
    va_start(args, pattern);
    ZCB_VCatF(self, pattern, args);
    va_end(args);

    return self;
}

ZombieCharBuf*
ZCB_wrap_str(void *allocation, const char *ptr, size_t size)
{
    ZombieCharBuf *self = (ZombieCharBuf*)allocation;
    self->ref.count    = 1;
    self->vtable       = ZOMBIECHARBUF;
    self->cap          = 0;
    self->size         = size;
    self->ptr          = (char*)ptr;
    return self;
}

ZombieCharBuf*
ZCB_wrap(void *allocation, const CharBuf *source)
{
    return ZCB_wrap_str(allocation, source->ptr, source->size);
}

size_t
ZCB_size()
{
    return sizeof(ZombieCharBuf);
}

void
ZCB_destroy(ZombieCharBuf *self)
{
    THROW(ERR, "Can't destroy a ZombieCharBuf ('%o')", self);
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

