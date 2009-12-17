#define C_KINO_OBJ
#define C_KINO_ZOMBIECHARBUF
#include "XSBind.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/StringHelper.h"

/* Convert a Perl hash into a KS Hash.  Caller takes responsibility for a
 * refcount.
 */
static kino_Hash*
phash_to_khash(HV *phash);

/* Convert a Perl array into a KS VArray.  Caller takes responsibility for a
 * refcount.
 */
static kino_VArray*
parray_to_karray(AV *parray);

kino_Obj*
XSBind_new_blank_obj(SV *either_sv)
{
    kino_VTable *vtable;

    /* Get a vtable. */
    if (   sv_isobject(either_sv) 
        && sv_derived_from(either_sv, "KinoSearch::Obj")
    ) {
        IV iv_ptr = SvIV(SvRV(either_sv));
        kino_Obj *self = INT2PTR(kino_Obj*, iv_ptr);
        vtable = self->vtable;
    }
    else {
        STRLEN len;
        char *ptr = SvPVutf8(either_sv, len);
        kino_ZombieCharBuf klass = kino_ZCB_make_str(ptr, len);
        vtable = kino_VTable_singleton((kino_CharBuf*)&klass, NULL);
    }

    return Kino_VTable_Make_Obj(vtable);
}

chy_bool_t
XSBind_sv_defined(SV *sv)
{
    if (!sv || !SvANY(sv)) { return false; }
    if (SvGMAGICAL(sv)) { mg_get(sv); }
    return SvOK(sv);
}

kino_Obj*
XSBind_sv_to_kobj(SV *sv, kino_VTable *vtable) 
{
    kino_Obj *retval = XSBind_maybe_sv_to_kobj(sv, vtable);
    if (!retval) THROW(KINO_ERR, "Not a %o", Kino_VTable_Get_Name(vtable));
    return retval;
}

kino_Obj*
XSBind_sv_to_kobj_or_zcb(SV *sv, kino_VTable *vtable, kino_ZombieCharBuf *zcb)
{
    kino_Obj *retval = NULL;
    if (!sv || !XSBind_sv_defined(sv)) {
        THROW(KINO_ERR, "Need a %o, but got NULL or undef", 
            Kino_VTable_Get_Name(vtable));
    }
    else if (   sv_isobject(sv) 
             && sv_derived_from(sv,
                 (char*)Kino_CB_Get_Ptr8(Kino_VTable_Get_Name(vtable)))
    ) {
        IV tmp = SvIV( SvRV(sv) );
        retval = INT2PTR(kino_Obj*, tmp);
    }
    else if (   vtable == KINO_ZOMBIECHARBUF
             || vtable == KINO_VIEWCHARBUF
             || vtable == KINO_CHARBUF
             || vtable == KINO_OBJ
    ) {
        STRLEN size;
        char *ptr = SvPVutf8(sv, size);
        Kino_ViewCB_Assign_Str(zcb, ptr, size);
        retval = (kino_Obj*)zcb;
    }
    else THROW(KINO_ERR, "Not a %o", Kino_VTable_Get_Name(vtable));
    return retval;
}

kino_Obj*
XSBind_maybe_sv_to_kobj(SV *sv, kino_VTable *vtable) 
{
    kino_Obj *retval = NULL;
    if (sv && XSBind_sv_defined(sv)) {
        if (   sv_isobject(sv) 
            && sv_derived_from(sv, 
                 (char*)Kino_CB_Get_Ptr8(Kino_VTable_Get_Name(vtable)))
        ) {
            IV tmp = SvIV( SvRV(sv) );
            retval = INT2PTR(kino_Obj*, tmp);
        }
        else if (SvROK(sv)) {
            SV *inner = SvRV(sv);
            if (SvTYPE(inner) == SVt_PVAV) {
                if (   vtable == KINO_VARRAY
                    || vtable == KINO_OBJ
                ) {
                    retval = (kino_Obj*)parray_to_karray((AV*)inner);
                }
            }
            else if (SvTYPE(inner) == SVt_PVHV) {
                if (   vtable == KINO_HASH
                    || vtable == KINO_OBJ
                ) {
                    retval = (kino_Obj*)phash_to_khash((HV*)inner);
                }
            }

            if(retval) {
                /* Mortalize the KS-ified copy of the Perl data structure. */
                SV *mortal = Kino_Obj_To_Host(retval);
                KINO_DECREF(retval);
                sv_2mortal(mortal);
            }
        }
    }
    return retval;
}

kino_ZombieCharBuf
XSBind_sv_to_class_name(SV* either_sv) 
{
    if (sv_isobject(either_sv)) {
        char *name = HvNAME(SvSTASH(SvRV(either_sv)));
        return kino_ZCB_make_str(name, strlen(name));
    }
    else {
        STRLEN size;
        char *name = SvPVutf8(either_sv, size);
        return kino_ZCB_make_str(name, size);
    }
}

SV*
XSBind_bb_to_sv(const kino_ByteBuf *bb) 
{
    return bb 
        ? newSVpvn(Kino_BB_Get_Buf(bb), Kino_BB_Get_Size(bb)) 
        : newSV(0);
}

SV*
XSBind_cb_to_sv(const kino_CharBuf *cb) 
{
    if (!cb) return newSV(0);
    else {
        SV *sv = newSVpvn((char*)Kino_CB_Get_Ptr8(cb), Kino_CB_Get_Size(cb));
        SvUTF8_on(sv);
        return sv;
    }
}

static kino_Hash*
phash_to_khash(HV *phash)
{
    chy_u32_t  num_keys = hv_iterinit(phash);
    kino_Hash *retval   = kino_Hash_new(num_keys);

    while (num_keys--) {
        HE *entry = hv_iternext(phash);
        STRLEN key_len;
        /* Copied from Perl 5.10.0 HePV macro, because the HePV macro in
         * earlier versions of Perl triggers a compiler warning. */
        char *key = HeKLEN(entry) == HEf_SVKEY
                  ? SvPV(HeKEY_sv(entry), key_len) 
                  : ((key_len = HeKLEN(entry)), HeKEY(entry));
        SV *value_sv = HeVAL(entry);
        if (!kino_StrHelp_utf8_valid(key, key_len)) {
            /* Force key to UTF-8. This is kind of a buggy area for Perl, and
             * may result in round-trip weirdness. */
            SV *key_sv = HeSVKEY_force(entry);
            key = SvPVutf8(key_sv, key_len);
        }
        Kino_Hash_Store_Str(retval, key, key_len, 
            XSBind_perl_to_kino(value_sv));
    }

    return retval;
}

static kino_VArray*
parray_to_karray(AV *parray)
{
    const chy_u32_t size = av_len(parray) + 1;
    kino_VArray *retval = kino_VA_new(size);
    chy_u32_t i;

    for (i = 0; i < size; i++) {
        SV **elem_sv = av_fetch(parray, i, false);
        if (elem_sv) {
            kino_Obj *elem = XSBind_perl_to_kino(*elem_sv);
            if (elem) { Kino_VA_Store(retval, i, elem); }
        }
    }
    Kino_VA_Resize(retval, size); /* needed if last elem is NULL */

    return retval;
}

kino_Obj*
XSBind_perl_to_kino(SV *sv)
{
    kino_Obj *retval = NULL;

    if (sv && XSBind_sv_defined(sv)) {
        if (SvROK(sv)) {
            SV *inner = SvRV(sv);
            if (SvTYPE(inner) == SVt_PVAV) {
                retval = (kino_Obj*)parray_to_karray((AV*)inner);
            }
            else if (SvTYPE(inner) == SVt_PVHV) {
                retval = (kino_Obj*)phash_to_khash((HV*)inner);
            }
            else if (   sv_isobject(sv) 
                     && sv_derived_from(sv, "KinoSearch::Obj")
            ) {
                IV tmp = SvIV(inner);
                retval = INT2PTR(kino_Obj*, tmp);
                (void)KINO_INCREF(retval);
            }
        }

        /* It's either a plain scalar or a non-KinoSearch Perl object. */
        if (!retval) {
            STRLEN len;
            char *ptr = SvPVutf8(sv, len);
            retval = (kino_Obj*)kino_CB_new_from_trusted_utf8(ptr, len);
        }
    }
    else if (sv) {
        if (SvTYPE(sv) == SVt_PVAV) {
            retval = (kino_Obj*)parray_to_karray((AV*)sv);
        }
        else if (SvTYPE(sv) == SVt_PVHV) {
            retval = (kino_Obj*)phash_to_khash((HV*)sv);
        }
    }

    return retval;
}

static SV*
karray_to_parray(kino_VArray *varray)
{
    AV *perl_array = newAV();
    chy_u32_t num_elems = Kino_VA_Get_Size(varray);

    if (num_elems) {
        chy_u32_t i;
        av_fill(perl_array, num_elems - 1);
        for (i = 0; i < num_elems; i++) {
            kino_Obj *val = Kino_VA_Fetch(varray, i);
            if (val == NULL) {
                continue;
            }
            else {
                SV *const val_sv = XSBind_kobj_to_pobj(val);
                av_store(perl_array, i, val_sv);
            }
        }
    }

    return newRV_noinc((SV*)perl_array);
}

static SV*
khash_to_phash(kino_Hash *hash)
{
    HV *perl_hash = newHV();
    SV *key_sv    = newSV(1);
    kino_CharBuf *key;
    kino_Obj     *val;

    /* Prepare the SV key. */
    SvPOK_on(key_sv);
    SvUTF8_on(key_sv);

    Kino_Hash_Iter_Init(hash);
    while (Kino_Hash_Iter_Next(hash, (kino_Obj**)&key, &val)) {
        SV *val_sv = XSBind_kobj_to_pobj(val);
        if (!KINO_OBJ_IS_A(key, KINO_CHARBUF)) {
            KINO_THROW(KINO_ERR, 
                "Can't convert a key of class %o to a Perl hash key",
                Kino_Obj_Get_Class_Name(key));
        }
        else {
            STRLEN key_size = Kino_CB_Get_Size(key);
            char *key_sv_ptr = SvGROW(key_sv, key_size + 1); 
            memcpy(key_sv_ptr, Kino_CB_Get_Ptr8(key), key_size);
            SvCUR_set(key_sv, key_size);
            *SvEND(key_sv) = '\0';
            hv_store_ent(perl_hash, key_sv, val_sv, 0);
        }
    }
    SvREFCNT_dec(key_sv);

    return newRV_noinc((SV*)perl_hash);
}

SV*
XSBind_kobj_to_pobj(kino_Obj *obj)
{
    if (obj == NULL) 
        return newSV(0);
    else if (KINO_OBJ_IS_A(obj, KINO_CHARBUF))
        return XSBind_cb_to_sv((kino_CharBuf*)obj);
    else if (KINO_OBJ_IS_A(obj, KINO_BYTEBUF))
        return XSBind_bb_to_sv((kino_ByteBuf*)obj);
    else if (KINO_OBJ_IS_A(obj, KINO_VARRAY))
        return karray_to_parray((kino_VArray*)obj);
    else if (KINO_OBJ_IS_A(obj, KINO_HASH))
        return khash_to_phash((kino_Hash*)obj);
    else if (KINO_OBJ_IS_A(obj, KINO_FLOATNUM))
        return newSVnv(Kino_Num_To_F64(obj));
    else if (sizeof(IV) == 8 && KINO_OBJ_IS_A(obj, KINO_INTNUM)) {
        chy_i64_t num = Kino_Num_To_I64(obj);
        return newSViv((IV)num);
    }
    else if (sizeof(IV) == 4 && KINO_OBJ_IS_A(obj, KINO_INTEGER32)) {
        chy_i32_t num = (chy_i32_t)Kino_Num_To_I64(obj);
        return newSViv((IV)num);
    }
    else if (sizeof(IV) == 4 && KINO_OBJ_IS_A(obj, KINO_INTEGER64)) {
        chy_i64_t num = Kino_Num_To_I64(obj);
        return newSVnv((double)num); /* lossy */
    }
    else 
        return (SV*)Kino_Obj_To_Host(obj);
}

void
XSBind_enable_overload(void *pobj)
{
    SV *perl_obj = (SV*)pobj;
    HV *stash = SvSTASH(SvRV(perl_obj));
    char *package_name = HvNAME(stash);
    size_t size = strlen(package_name);

    /* This code is informed by the following snippet from Perl_sv_bless, from
     * sv.c:
     *
     *     if (Gv_AMG(stash))
     *         SvAMAGIC_on(sv);
     *     else
     *         (void)SvAMAGIC_off(sv);
     *
     * Gv_AMupdate is undocumented.  It is extracted from the Gv_AMG macro,
     * also undocumented, defined in sv.h:
     *
     *     #define Gv_AMG(stash)  (PL_amagic_generation && Gv_AMupdate(stash))
     * 
     * The purpose of the code is to turn on overloading for the class in
     * question.  It seems that as soon as overloading is on for any class,
     * anywhere, that PL_amagic_generation goes positive and stays positive,
     * so that Gv_AMupdate gets called with every bless() invocation.  Since
     * we need overloading for Doc and all its subclasses, we skip the check
     * and just update every time.
     */
    stash = gv_stashpvn((char*)package_name, size, true);
    Gv_AMupdate(stash);
    SvAMAGIC_on(perl_obj);
}

void
XSBind_allot_params(SV** stack, chy_i32_t start, chy_i32_t num_stack_elems, 
                    char* defaults_hash_name, ...)
{
    va_list args;
    HV *defaults_hash = get_hv(defaults_hash_name, 0);
    SV **target;
    chy_i32_t i;
    chy_i32_t args_left = (num_stack_elems - start) / 2;

    /* NOTE: the defaults hash must be declared using "our". */
    if (defaults_hash == NULL)
        THROW(KINO_ERR, "Can't find hash named %s", defaults_hash_name);

    /* Verify that our args come in pairs. Bail if there are no args. */
    if (num_stack_elems == start) return;
    if ((num_stack_elems - start) % 2 != 0)
        THROW(KINO_ERR, "Expecting hash-style params, got odd number of args");

    /* Validate param names. */
    for (i = start; i < num_stack_elems; i += 2) {
        SV *const key_sv = stack[i];
        STRLEN key_len;
        const char *key = SvPV(key_sv, key_len); /* assume ASCII labels */
        if (!hv_exists(defaults_hash, key, key_len)) {
            THROW(KINO_ERR, "Invalid parameter: '%s'", key);
        }
    }

    va_start(args, defaults_hash_name); 
    while (args_left && NULL != (target = va_arg(args, SV**))) {
        char *label = va_arg(args, char*);
        int label_len = va_arg(args, int);

        /* Iterate through stack looking for a label match. Work backwards so
         * that if the label is doubled up we get the last one. */
        for (i = num_stack_elems; i >= start + 2; i -= 2) {
            chy_i32_t tick = i - 2;
            SV *const key_sv = stack[tick];
            const chy_i32_t comparison = kino_StrHelp_compare_strings(
                label, SvPVX(key_sv), label_len, SvCUR(key_sv));
            if (comparison == 0) {
                *target = stack[tick + 1];
                args_left--;
                break;
            }
        }
    }
    va_end(args);
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

