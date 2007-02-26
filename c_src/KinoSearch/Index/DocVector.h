#ifndef H_KINO_DOCVECTOR
#define H_KINO_DOCVECTOR 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "charmony.h"

/* Return ref to a hash where the keys are term texts and the values are
 * encoded positional data.
 */
HV*
kino_DocVec_extract_tv_cache(SV *tv_string_sv);

/* Decompress positional data. 
 */
void
kino_DocVec_extract_posdata(SV *posdata_sv, AV *positions_av, 
                            AV *starts_av,  AV *ends_av);

#endif /* H_KINO_DOCVECTOR */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

