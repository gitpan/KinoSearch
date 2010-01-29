#define C_KINO_LEXINDEX
#define C_KINO_TERMINFO
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/LexIndex.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Index/TermStepper.h"
#include "KinoSearch/Plan/Architecture.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/InStream.h"

/* Read the data we've arrived at after a seek operation. */
static void
S_read_entry(LexIndex *self);

LexIndex*
LexIndex_new(Schema *schema, Folder *folder, Segment *segment, 
             const CharBuf *field)
{
    LexIndex *self = (LexIndex*)VTable_Make_Obj(LEXINDEX);
    return LexIndex_init(self, schema, folder, segment, field);
}

LexIndex*
LexIndex_init(LexIndex *self, Schema *schema, Folder *folder, 
              Segment *segment, const CharBuf *field)
{
    i32_t    field_num = Seg_Field_Num(segment, field);
    CharBuf *seg_name  = Seg_Get_Name(segment);
    CharBuf *ixix_file = CB_newf("%o/lexicon-%i32.ixix", seg_name, field_num);
    CharBuf *ix_file   = CB_newf("%o/lexicon-%i32.ix", seg_name, field_num);
    Architecture *arch = Schema_Get_Architecture(schema);

    /* Init. */
    self->tinfo        = TInfo_new(0);
    self->tick         = 0;

    /* Derive */
    self->field_type = Schema_Fetch_Type(schema, field);
    if (!self->field_type) {
        CharBuf *mess = MAKE_MESS("Unknown field: '%o'", field);
        DECREF(ix_file);
        DECREF(ixix_file);
        DECREF(self);
        Err_throw_mess(ERR, mess);
    }
    INCREF(self->field_type);
    self->term_stepper = FType_Make_Term_Stepper(self->field_type);
    self->ixix_in = Folder_Open_In(folder, ixix_file);
    if (!self->ixix_in) {
        Err *error = (Err*)INCREF(Err_get_error());
        DECREF(ix_file);
        DECREF(ixix_file);
        DECREF(self);
        RETHROW(error);
    }
    self->ix_in = Folder_Open_In(folder, ix_file);
    if (!self->ix_in) {
        Err *error = (Err*)INCREF(Err_get_error());
        DECREF(ix_file);
        DECREF(ixix_file);
        DECREF(self);
        RETHROW(error);
    }
    self->index_interval = Arch_Index_Interval(arch);
    self->skip_interval  = Arch_Skip_Interval(arch);
    self->size    = (i32_t)(InStream_Length(self->ixix_in) / sizeof(i64_t));
    self->offsets = (i64_t*)InStream_Buf(self->ixix_in,
        (size_t)InStream_Length(self->ixix_in));

    DECREF(ixix_file);
    DECREF(ix_file);

    return self;
}

void
LexIndex_destroy(LexIndex *self) 
{    
    DECREF(self->field_type);
    DECREF(self->ixix_in);
    DECREF(self->ix_in);
    DECREF(self->term_stepper);
    DECREF(self->tinfo);
    SUPER_DESTROY(self, LEXINDEX);
}

i32_t
LexIndex_get_term_num(LexIndex *self)
{
    return (self->index_interval * self->tick) - 1;
}

Obj*
LexIndex_get_term(LexIndex *self) 
{ 
    return TermStepper_Get_Value(self->term_stepper); 
}

TermInfo*
LexIndex_get_term_info(LexIndex *self) { return self->tinfo; }

static void
S_read_entry(LexIndex *self)
{
    InStream *ix_in  = self->ix_in;
    TermInfo *tinfo  = self->tinfo;
    i64_t offset = (i64_t)NumUtil_decode_bigend_u64(self->offsets + self->tick);
    InStream_Seek(ix_in, offset);
    TermStepper_Read_Key_Frame(self->term_stepper, ix_in);
    tinfo->doc_freq     = InStream_Read_C32(ix_in);
    tinfo->post_filepos = InStream_Read_C64(ix_in);
    tinfo->skip_filepos = tinfo->doc_freq >= self->skip_interval
                        ? InStream_Read_C64(ix_in) : 0;
    tinfo->lex_filepos  = InStream_Read_C64(ix_in);
}

void
LexIndex_seek(LexIndex *self, Obj *target)
{
    TermStepper *term_stepper = self->term_stepper;
    InStream    *ix_in        = self->ix_in;
    FieldType   *type         = self->field_type;
    i32_t        lo           = 0;
    i32_t        hi           = self->size - 1;
    i32_t        result       = -100;

    if (target == NULL || self->size == 0) { 
        self->tick = 0;
        return;
    }
    else {
        if ( !Obj_Is_A(target, CHARBUF)) {
            THROW(ERR, "Target is a %o, and not comparable to a %o",
                Obj_Get_Class_Name(target), VTable_Get_Name(CHARBUF));
        }
        /* TODO: 
        Obj *first_obj = VA_Fetch(terms, 0);
        if ( !Obj_Is_A(target, Obj_Get_VTable(first_obj)) ) {
            THROW(ERR, "Target is a %o, and not comparable to a %o",
                Obj_Get_Class_Name(target), Obj_Get_Class_Name(first_obj));
        }
        */
    }

    /* Divide and conquer. */
    while (hi >= lo) {
        const i32_t mid = lo + ((hi - lo) / 2);
        const i64_t offset 
            = (i64_t)NumUtil_decode_bigend_u64(self->offsets + mid);
        i32_t comparison;
        InStream_Seek(ix_in, offset);
        TermStepper_Read_Key_Frame(term_stepper, ix_in);

        comparison = FType_Compare_Values(type, target,
            TermStepper_Get_Value(term_stepper));
        if (comparison < 0) {
            hi = mid - 1;
        }
        else if (comparison > 0) {
            lo = mid + 1;
        }
        else {
            result = mid;
            break;
        }
    }

    /* Record the index of the entry we've seeked to, then read entry. */
    self->tick = hi == -1   ? 0  /* indicating that target lt first entry */
           : result == -100 ? hi /* if result is still -100, it wasn't set */
           : result;
    S_read_entry(self);
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

