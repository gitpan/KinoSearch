#ifndef H_KINO_SCHEMA
#define H_KINO_SCHEMA 1

#include "KinoSearch/Util/Obj.r"

struct kino_Folder;
struct kino_FieldSpec;
struct kino_Hash;
struct kino_Posting;
struct kino_Similarity;
struct kino_VArray;

typedef struct kino_Schema kino_Schema;
typedef struct KINO_SCHEMA_VTABLE KINO_SCHEMA_VTABLE;

KINO_CLASS("KinoSearch::Schema", "Schema", "KinoSearch::Util::Obj");

struct kino_Schema {
    KINO_SCHEMA_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_Similarity   *sim;
    struct kino_Hash         *fspecs;
    struct kino_Hash         *sims;
    struct kino_Hash         *postings;
    void                     *analyzers;
    void                     *analyzer;
    chy_i32_t                 index_interval;
    chy_i32_t                 skip_interval;
};

/* Constructor.
 */
kino_Schema*
kino_Schema_new(const char *class_name, void *analyzer, void *analyzers,
                struct kino_Similarity *sim, chy_i32_t index_interval,
                chy_i32_t skip_interval);

void
kino_Schema_add_field(kino_Schema *self, 
                      const struct kino_ByteBuf *field_name,
                      struct kino_FieldSpec *field_spec);
KINO_METHOD("Kino_Schema_Add_Field");

struct kino_FieldSpec*
kino_Schema_fetch_fspec(kino_Schema *self, 
                        const struct kino_ByteBuf *field_name);
KINO_METHOD("Kino_Schema_Fetch_FSpec");

struct kino_Similarity*
kino_Schema_fetch_sim(kino_Schema *self, 
                      const struct kino_ByteBuf *field_name);
KINO_METHOD("Kino_Schema_Fetch_Sim");

/* Return a fresh Posting object as dictated by the field's FieldSpec.  Note
 * that this is a new object, unlike other Fetch_Xxxx methods, so the caller
 * must take responsibility for its destruction.
 */
struct kino_Posting*
kino_Schema_fetch_posting(kino_Schema *self, 
                          const struct kino_ByteBuf *field_name);
KINO_METHOD("Kino_Schema_Fetch_Posting");

chy_u32_t
kino_Schema_num_fields(kino_Schema *self);
KINO_METHOD("Kino_Schema_Num_Fields");

struct kino_VArray*
kino_Schema_all_fields(kino_Schema *self);
KINO_METHOD("Kino_Schema_All_Fields");

void 
kino_Schema_destroy(kino_Schema *self);
KINO_METHOD("Kino_Schema_Destroy");

KINO_END_CLASS

#endif /* H_KINO_SCHEMA */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

