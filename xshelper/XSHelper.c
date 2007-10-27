/* WARNING -- this file may be a copy.  The original lives in xshelper/.
 */

#include "XSHelper.h"

HV*
build_args_hash(SV** stack, chy_i32_t start, chy_i32_t num_stack_elems, 
                char* defaults_hash_name)
{
    HV *defaults_hash = get_hv(defaults_hash_name, 0);
    HV *args_hash = (HV*)sv_2mortal( (SV*)newHV() );
    chy_i32_t stack_pos = start;

    /* NOTE: the defaults hash must be declared using "our" */
    if (defaults_hash == NULL)
        CONFESS("Can't find hash named %s", defaults_hash_name);

    /* verify that our args come in pairs */
    if ((num_stack_elems - start) % 2 != 0)
        CONFESS("Expecting hash-style params, got odd number of args");

    /* make the args hash a copy of the defaults hash */
    (void)hv_iterinit(defaults_hash);
    while (1) {
        char *key;
        I32 key_len;
        SV *const val_sv = hv_iternextsv(defaults_hash, &key, &key_len);
        if (!val_sv)
            break;
        hv_store(args_hash, key, key_len, newSVsv(val_sv), 0);
    }

    /* verify and copy hash-style params into args hash from stack */
    while (stack_pos < num_stack_elems) {
        SV * val_sv;
        SV *const key_sv = stack[stack_pos++];
        STRLEN key_len;
        char *key = SvPV(key_sv, key_len);
        if (!hv_exists(args_hash, key, key_len)) {
            CONFESS("Invalid parameter: '%s'", key);
        }
        val_sv = stack[stack_pos++];
        hv_store(args_hash, key, key_len, newSVsv(val_sv), 0);
    }
    
    return args_hash;
}


SV* 
extract_sv(HV* hash, char* key, chy_i32_t key_len) 
{
    SV **const sv_ptr = hv_fetch(hash, key, key_len, 0);
    if (sv_ptr == NULL)
        CONFESS("Failed to retrieve hash entry '%s'", key);
    return *sv_ptr;
}

UV
extract_uv(HV* hash, char* key, chy_i32_t key_len) 
{
    SV **const sv_ptr = hv_fetch(hash, key, key_len, 0);
    if (sv_ptr == NULL)
        CONFESS("Failed to retrieve hash entry '%s'", key);
    return SvUV(*sv_ptr);
}

IV
extract_iv(HV* hash, char* key, chy_i32_t key_len) 
{
    SV **const sv_ptr = hv_fetch(hash, key, key_len, 0);
    if (sv_ptr == NULL)
        CONFESS("Failed to retrieve hash entry '%s'", key);
    return SvIV(*sv_ptr);
}

NV
extract_nv(HV* hash, char* key, chy_i32_t key_len) 
{
    SV **const sv_ptr = hv_fetch(hash, key, key_len, 0);
    if (sv_ptr == NULL)
        CONFESS("Failed to retrieve hash entry '%s'", key);
    return SvNV(*sv_ptr);
}

void*
extract_obj(HV *hash, char *key, STRLEN key_len, char *class)
{
    SV **const sv_ptr = hv_fetch(hash, key, key_len, 0);
    void* retval = NULL;
    if (sv_ptr == NULL)
        CONFESS("Failed to retrieve hash entry '%s'", key);
    if (sv_derived_from( *sv_ptr, class )) {
        IV temp = SvIV( (SV*)SvRV(*sv_ptr) );
        retval = INT2PTR(void*, temp);
    }
    else {
        CONFESS("not a %s", class);
    }
    return retval;
}

void*
maybe_extract_obj(HV *hash, char *key, STRLEN key_len, char *class)
{
    SV **const sv_ptr = hv_fetch(hash, key, key_len, 0);
    void* retval = NULL;
    if (sv_ptr != NULL && SvOK(*sv_ptr)) {
        if (sv_derived_from( *sv_ptr, class )) {
            IV temp = SvIV( (SV*)SvRV(*sv_ptr) );
            retval = INT2PTR(void*, temp);
        }
        else {
            CONFESS("not a %s", class);
        }
    }
    return retval;
}

char*
derive_class(SV* either_sv) 
{
    return sv_isobject(either_sv) 
        ? HvNAME(SvSTASH(SvRV(either_sv)))
        : SvPV_nolen(either_sv);
}

chy_bool_t
less_than_sviv(const void *a, const void *b) 
{
    if ( SvIV((SV*)a) < SvIV((SV*)b) ) {
        return true;
    }
    else {
        return false;
    }
}

void
kino_sv_free(void *sv) 
{
    sv_free((SV*)sv);
}

kino_ByteBuf*
sv_to_new_bb(SV *sv) 
{
    STRLEN len;
    char *string = SvPV(sv, len);
    return kino_BB_new_str(string, len);
}

SV*
bb_to_sv(kino_ByteBuf *bb) 
{
    return newSVpvn(bb->ptr, bb->len);
}

SV*
kobj_to_pobj(void *vobj)
{
    kino_Obj *const obj = (kino_Obj*)vobj;
    SV *perl_obj = newSV(0);
    REFCOUNT_INC(obj);
    sv_setref_pv(perl_obj, obj->_->class_name, obj);
    return perl_obj;
}

SV*
nat_obj_to_pobj(kino_Obj *obj)
{
    if (obj == NULL) 
        return newSV(0);
    else if (KINO_OBJ_IS_A(obj, KINO_BYTEBUF))
        return bb_to_sv((kino_ByteBuf*)obj);
    else if (KINO_OBJ_IS_A(obj, KINO_VARRAY))
        return karray_to_parray((kino_VArray*)obj);
    else if (KINO_OBJ_IS_A(obj, KINO_HASH))
        return khash_to_phash((kino_Hash*)obj);
    else 
        return kobj_to_pobj(obj);
}

SV*
karray_to_parray(kino_VArray *varray)
{
    AV *perl_array = newAV();
    chy_u32_t i;

    av_extend(perl_array, varray->size);
    for (i = 0; i < varray->size; i++) {
        kino_Obj *val = Kino_VA_Fetch(varray, i);
        if (val == NULL) {
            continue;
        }
        else {
            SV *const val_sv = nat_obj_to_pobj(val);
            av_store(perl_array, i, val_sv);
        }
    }

    return newRV_noinc((SV*)perl_array);
}

SV*
khash_to_phash(kino_Hash *hash)
{
    HV *perl_hash = newHV();
    kino_ByteBuf *key;
    kino_Obj     *val;

    Kino_Hash_Iter_Init(hash);
    while (Kino_Hash_Iter_Next(hash, &key, &val)) {
        SV *val_sv = nat_obj_to_pobj(val);
        hv_store(perl_hash, key->ptr, key->len, val_sv, 0);
    }

    return newRV_noinc((SV*)perl_hash);
}

/* Copyright 2005-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

