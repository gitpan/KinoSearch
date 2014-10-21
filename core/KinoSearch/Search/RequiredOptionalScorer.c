#define C_KINO_REQUIREDOPTIONALSCORER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/RequiredOptionalScorer.h"
#include "KinoSearch/Index/Similarity.h"

RequiredOptionalScorer*
ReqOptScorer_new(Similarity *similarity, Matcher *required_matcher, 
                 Matcher *optional_matcher) 
{
    RequiredOptionalScorer *self 
        = (RequiredOptionalScorer*)VTable_Make_Obj(REQUIREDOPTIONALSCORER);
    return ReqOptScorer_init(self, similarity, required_matcher, 
        optional_matcher);
}

RequiredOptionalScorer*
ReqOptScorer_init(RequiredOptionalScorer *self, Similarity *similarity, 
                  Matcher *required_matcher, Matcher *optional_matcher) 
{
    VArray *children = VA_new(2);
    VA_Push(children, INCREF(required_matcher));
    VA_Push(children, INCREF(optional_matcher));
    PolyMatcher_init((PolyMatcher*)self, children, similarity);

    // Assign. 
    self->req_matcher       = (Matcher*)INCREF(required_matcher);
    self->opt_matcher       = (Matcher*)INCREF(optional_matcher);

    // Init. 
    self->opt_matcher_first_time = true;

    DECREF(children);
    return self;
}

void
ReqOptScorer_destroy(RequiredOptionalScorer *self) 
{
    DECREF(self->req_matcher);
    DECREF(self->opt_matcher);
    SUPER_DESTROY(self, REQUIREDOPTIONALSCORER);
}

int32_t
ReqOptScorer_next(RequiredOptionalScorer *self)
{
    return Matcher_Next(self->req_matcher);
}

int32_t
ReqOptScorer_advance(RequiredOptionalScorer *self, int32_t target)
{
    return Matcher_Advance(self->req_matcher, target);
}

int32_t
ReqOptScorer_get_doc_id(RequiredOptionalScorer *self)
{
    return Matcher_Get_Doc_ID(self->req_matcher);
}

float
ReqOptScorer_score(RequiredOptionalScorer *self)
{
    int32_t const current_doc = Matcher_Get_Doc_ID(self->req_matcher);

    if (self->opt_matcher_first_time) {
        self->opt_matcher_first_time = false;
        if ( !Matcher_Advance(self->opt_matcher, current_doc) ) {
            DECREF(self->opt_matcher);
            self->opt_matcher = NULL;
        }
    }

    if (self->opt_matcher == NULL) {
        return Matcher_Score(self->req_matcher);
    }
    else {
        int32_t opt_matcher_doc = Matcher_Get_Doc_ID(self->opt_matcher);

        if (opt_matcher_doc < current_doc) {
            opt_matcher_doc = Matcher_Advance(self->opt_matcher, current_doc);
            if (!opt_matcher_doc) {
                DECREF(self->opt_matcher);
                self->opt_matcher = NULL;
                return Matcher_Score(self->req_matcher);
            }
        }

        if (opt_matcher_doc == current_doc) {
            float score = Matcher_Score(self->req_matcher)
                        + Matcher_Score(self->opt_matcher);
            score *= self->coord_factors[2];
            return score;
        }
        else {
            return Matcher_Score(self->req_matcher);
        }
    }
}

/* Copyright 2007-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

