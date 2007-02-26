#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SCORER_VTABLE
#include "KinoSearch/Search/Scorer.r"

#include "KinoSearch/Search/Similarity.r"


float
Scorer_score(Scorer *self) 
{
    UNUSED_VAR(self);
    CONFESS("Scorer_Score must be defined in a subclass");
    UNREACHABLE_RETURN(float);
}

bool_t
Scorer_next(Scorer *self) 
{
    UNUSED_VAR(self);
    CONFESS("Scorer_Next must be defined in a subclass");
    UNREACHABLE_RETURN(bool_t);
}

u32_t
Scorer_doc(Scorer *self) 
{
    UNUSED_VAR(self);
    CONFESS("Scorer_Doc must be defined in a subclass");
    UNREACHABLE_RETURN(u32_t);
}

bool_t
Scorer_skip_to(Scorer *self, u32_t target) 
{
    do {
        if ( !Scorer_Next(self) )
            return false;
    } while ( target > Scorer_Doc(self) );

    return true;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

