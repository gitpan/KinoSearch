#include "xs/XSBind.h"

#include "KinoSearch/Index/DocReader.h"
#include "KinoSearch/Doc/HitDoc.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Util/Host.h"

kino_Obj*
kino_DefDocReader_fetch(kino_DefaultDocReader *self, chy_i32_t doc_id, 
                        float score, chy_i32_t offset)
{
    kino_Schema   *const schema = self->schema;
    kino_InStream *const dat_in = self->dat_in;
    kino_InStream *const ix_in  = self->ix_in;
    HV *fields = newHV();
    chy_i64_t start;
    chy_u32_t num_fields;
    SV *field_name_sv = newSV(1);

    /* Get data file pointer from index, read number of fields. */
    Kino_InStream_Seek(ix_in, (chy_i64_t)doc_id * 8);
    start = Kino_InStream_Read_U64(ix_in);
    Kino_InStream_Seek(dat_in, start);
    num_fields = Kino_InStream_Read_C32(dat_in);

    /* Decode stored data and build up the doc field by field. */
    while (num_fields--) {
        STRLEN  field_name_len;
        char   *field_name_ptr;
        SV     *value_sv;
        STRLEN  value_len;
        kino_FieldType *type;
        kino_ZombieCharBuf field_name_zcb = KINO_ZCB_BLANK;

        /* Read field name. */
        field_name_len = Kino_InStream_Read_C32(dat_in);
        field_name_ptr = SvGROW(field_name_sv, field_name_len + 1);
        Kino_InStream_Read_Bytes(dat_in, field_name_ptr, field_name_len);
        SvPOK_on(field_name_sv);
        SvCUR_set(field_name_sv, field_name_len);
        SvUTF8_on(field_name_sv);
        *SvEND(field_name_sv) = '\0';

        /* Find the Field's FieldType. */
        Kino_ZCB_Assign_Str(&field_name_zcb, field_name_ptr, field_name_len);
        type = Kino_Schema_Fetch_Type(schema, (kino_CharBuf*)&field_name_zcb);

        /* Read the field value. */
        value_len = Kino_InStream_Read_C32(dat_in);
        value_sv  = newSV((value_len ? value_len : 1));
        Kino_InStream_Read_Bytes(dat_in, SvPVX(value_sv), value_len);
        SvCUR_set(value_sv, value_len);
        *SvEND(value_sv) = '\0';
        SvPOK_on(value_sv);

        /* Set UTF-8 flag. */
        if (!Kino_FType_Binary(type)) {
            SvUTF8_on(value_sv);
        }

        /* Store the value. */
        hv_store_ent(fields, field_name_sv, value_sv, 0);
    }
    SvREFCNT_dec(field_name_sv);

    {
        kino_HitDoc *retval = kino_HitDoc_new(fields, doc_id + offset, score);
        SvREFCNT_dec((SV*)fields);
        return (kino_Obj*)retval;
    }
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

