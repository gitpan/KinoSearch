#define C_KINO_INVERTER
#define C_KINO_ZOMBIECHARBUF
#define C_KINO_INVERTERENTRY
#include "xs/XSBind.h"
#include "KinoSearch/Index/Inverter.h"
#include "KinoSearch/Doc.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/FieldType/BlobType.h"
#include "KinoSearch/FieldType/NumericType.h"
#include "KinoSearch/FieldType/TextType.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Obj/ByteBuf.h"
#include "KinoSearch/Schema.h"

static kino_InverterEntry*
S_fetch_entry(kino_Inverter *self, HE *hash_entry)
{
    kino_Schema *const schema = self->schema;
    STRLEN key_len;
    /* Copied from Perl 5.10.0 HePV macro, because the HePV macro in
     * earlier versions of Perl triggers a compiler warning. */
    char *key = HeKLEN(hash_entry) == HEf_SVKEY
              ? SvPV(HeKEY_sv(hash_entry), key_len) 
              : ((key_len = HeKLEN(hash_entry)), HeKEY(hash_entry));
    kino_ZombieCharBuf field = kino_ZCB_make_str(key, key_len);
    chy_i32_t field_num 
        = Kino_Seg_Field_Num(self->segment, (kino_CharBuf*)&field);

    if (!field_num) {
        /* This field seems not to be in the segment yet.  Try to find it in
         * the Schema. */
        if (!Kino_Schema_Fetch_Type(schema, (kino_CharBuf*)&field)) {
            /* OK, it could be that the field name contains non-ASCII
             * characters, but the hash key is encoded as Latin 1.  So, we
             * force hash key into an SV and ask for a UTF-8 PV.  This is
             * less efficient, so field names really ought to be ASCII. */
            SV *key_sv = HeSVKEY_force(hash_entry);
            key = SvPVutf8(key_sv, key_len);
            Kino_ZCB_Assign_Str(&field, key, key_len);
            if (!Kino_Schema_Fetch_Type(schema, (kino_CharBuf*)&field)) {
                /* We've truly failed to find the field.  The user must
                 * not have spec'd it. */
                THROW(KINO_ERR, "Unknown field name: '%s'", key);
            }
        }

        /* The field is in the Schema.  Get a field num from the Segment. */
        field_num = Kino_Seg_Add_Field(self->segment, (kino_CharBuf*)&field);
    }

    {
        kino_InverterEntry *entry 
            = (kino_InverterEntry*)Kino_VA_Fetch(self->entry_pool, field_num);
        if (!entry) {
            entry 
                = kino_InvEntry_new(schema, (kino_CharBuf*)&field, field_num);
            Kino_VA_Store(self->entry_pool, field_num, (kino_Obj*)entry);
        }
        return entry;
    }
}

void
kino_Inverter_invert_doc(kino_Inverter *self, kino_Doc *doc)
{
    HV          *const fields = Kino_Doc_Get_Fields(doc);
    I32          num_keys     = hv_iterinit(fields);

    /* Prepare for the new doc. */
    Kino_Inverter_Set_Doc(self, doc);

    /* Extract and invert the doc's fields. */
    while (num_keys--) {
        HE *hash_entry = hv_iternext(fields);
        kino_InverterEntry *inv_entry = S_fetch_entry(self, hash_entry);
        SV *value_sv = HeVAL(hash_entry);
        kino_FieldType *type = inv_entry->type;

        /* Get the field value, forcing text fields to UTF-8. */
        switch (
            Kino_FType_Primitive_ID(type) & kino_FType_PRIMITIVE_ID_MASK
        ) {
            case kino_FType_TEXT: {
                STRLEN val_len;
                char *val_ptr = SvPVutf8(value_sv, val_len);
                Kino_ViewCB_Assign_Str(inv_entry->value, val_ptr, val_len);
                break;
            }
            case kino_FType_BLOB: {
                STRLEN val_len;
                char *val_ptr = SvPV(value_sv, val_len);
                Kino_ViewBB_Assign_Bytes(inv_entry->value, val_ptr, val_len);
                break;
            }
            case kino_FType_INT32: {
                kino_Integer32* value = (kino_Integer32*)inv_entry->value;
                Kino_Int32_Set_Value(value, SvIV(value_sv));
                break;
            }
            case kino_FType_INT64: {
                kino_Integer64* value = (kino_Integer64*)inv_entry->value;
                chy_i64_t val = sizeof(IV) == 8 
                              ? SvIV(value_sv) 
                              : (chy_i64_t)SvNV(value_sv); /* lossy */
                Kino_Int64_Set_Value(value, val);
                break;
            }
            case kino_FType_FLOAT32: {
                kino_Float32* value = (kino_Float32*)inv_entry->value;
                Kino_Float32_Set_Value(value, (float)SvNV(value_sv));
                break;
            }
            case kino_FType_FLOAT64: {
                kino_Float64* value = (kino_Float64*)inv_entry->value;
                Kino_Float64_Set_Value(value, SvNV(value_sv));
                break;
            }
            default:
                THROW(KINO_ERR, "Unrecognized type: %o", type);
        }

        Kino_Inverter_Add_Field(self, inv_entry);
    }
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

