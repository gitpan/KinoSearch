#ifndef H_KINO_SCHEMA
#define H_KINO_SCHEMA 1

#include "KinoSearch/Util/Obj.r"

struct kino_Folder;
struct kino_FieldSpec;
struct kino_Hash;
struct kino_Similarity;
struct kino_VArray;

typedef struct kino_Schema kino_Schema;
typedef struct KINO_SCHEMA_VTABLE KINO_SCHEMA_VTABLE;

KINO_CLASS("KinoSearch::Schema", "Schema", "KinoSearch::Util::Obj");

struct kino_Schema {
    KINO_SCHEMA_VTABLE *_;
    kino_u32_t refcount;
    struct kino_Similarity   *sim;
    struct kino_Hash         *fspecs;
    struct kino_Hash         *sims;
    void                     *analyzers;
    void                     *analyzer;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_Schema*
kino_Schema_new(const char *class_name, struct kino_Hash *fspecs, 
                struct kino_Hash *sims, struct kino_Similarity *sim));

KINO_METHOD("Kino_Schema_Fetch_FSpec",
struct kino_FieldSpec*
kino_Schema_fetch_fspec(kino_Schema *self, 
                        const struct kino_ByteBuf *field_name));

KINO_METHOD("Kino_Schema_Fetch_Sim",
struct kino_Similarity*
kino_Schema_fetch_sim(kino_Schema *self, 
                      const struct kino_ByteBuf *field_name));

KINO_METHOD("Kino_Schema_Num_Fields",
kino_u32_t
kino_Schema_num_fields(kino_Schema *self));

KINO_METHOD("Kino_Schema_Destroy",
void 
kino_Schema_destroy(kino_Schema *self));

KINO_END_CLASS

#endif /* H_KINO_SCHEMA */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

