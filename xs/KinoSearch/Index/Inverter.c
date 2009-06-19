#include "xs/XSBind.h"
#include "KinoSearch/Index/Inverter.h"
#include "KinoSearch/Doc.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Index/Segment.h"
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
                THROW("Unknown field name: '%s'", key);
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
    kino_ZombieCharBuf value  = KINO_ZCB_BLANK;

    /* Prepare for the new doc. */
    Kino_Inverter_Set_Doc(self, doc);

    /* Extract and invert the doc's fields. */
    while (num_keys--) {
        HE *hash_entry = hv_iternext(fields);
        kino_InverterEntry *inv_entry = S_fetch_entry(self, hash_entry);
        SV *value_sv = HeVAL(hash_entry);
        STRLEN value_len;
        char *value_ptr;

        /* Get the field value, forcing text fields to UTF-8. */
        if (inv_entry->binary) {
            value_ptr = SvPV(value_sv, value_len);
        }
        else {
            value_ptr = SvPVutf8(value_sv, value_len);
        }
        Kino_ZCB_Assign_Str(&value, value_ptr, value_len);

        Kino_Inverter_Add_Field(self, inv_entry, (kino_Obj*)&value);
    }
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

