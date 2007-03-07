#ifndef H_KINO_FIELDDOCCOLLATOR
#define H_KINO_FIELDDOCCOLLATOR 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_FieldDocCollator kino_FieldDocCollator;
typedef struct KINO_FIELDDOCCOLLATOR_VTABLE KINO_FIELDDOCCOLLATOR_VTABLE;

struct kino_IntMap;

KINO_CLASS("KinoSearch::Search::FieldDocCollator", "FDocCollator",
    "KinoSearch::Util::Obj");

struct kino_FieldDocCollator {
    KINO_FIELDDOCCOLLATOR_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    kino_u32_t                 cap;
    kino_u32_t                 size;
    struct kino_IntMap       **sort_caches;
    kino_bool_t               *reversed;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_FieldDocCollator*
kino_FDocCollator_new());

/* Add a sort criteria.
 */
KINO_FUNCTION(
void
kino_FDocCollator_add(kino_FieldDocCollator *self, 
                      struct kino_IntMap *sort_cache, 
                      kino_bool_t reverse));

/* Compare two FieldDocs.
 */
KINO_FUNCTION(
kino_bool_t
kino_FDocCollator_less_than(const void *va, const void *vb));

/* Compare the components of two FieldDocs.
 */
KINO_METHOD("Kino_FDocCollator_Compare",
kino_bool_t
kino_FDocCollator_compare(kino_FieldDocCollator *self, 
                          kino_u32_t doc_num_a, float score_a, 
                          kino_u32_t doc_num_b, float score_b));


KINO_METHOD("Kino_FDocCollator_Destroy",
void
kino_FDocCollator_destroy(kino_FieldDocCollator *self));

KINO_END_CLASS

#endif /* H_KINO_FIELDDOCCOLLATOR */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
