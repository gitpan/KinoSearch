#define CHAZ_USE_SHORT_NAMES

#include "Charmonizer/Core/HeaderChecker.h"
#include "Charmonizer/Core/ConfWriter.h"
#include "Charmonizer/Core/Util.h"
#include "Charmonizer/Probe/AtomicOps.h"
#include <string.h>
#include <stdio.h>


void
AtomicOps_run(void) 
{
    chaz_bool_t has_libkern_osatomic_h = false;
    chaz_bool_t has_sys_atomic_h       = false;
    chaz_bool_t has_intrin_h           = false;

    ConfWriter_start_module("AtomicOps");

    if (HeadCheck_check_header("libkern/OSAtomic.h")) {
        has_libkern_osatomic_h = true;
        ConfWriter_append_conf("#define CHY_HAS_LIBKERN_OSATOMIC_H\n");
    }
    if (HeadCheck_check_header("sys/atomic.h")) {
        has_sys_atomic_h = true;
        ConfWriter_append_conf("#define CHY_HAS_SYS_ATOMIC_H\n");
    }
    if (   HeadCheck_check_header("windows.h")
        && HeadCheck_check_header("intrin.h")
    ) {
        has_intrin_h = true;
        ConfWriter_append_conf("#define CHY_HAS_INTRIN_H\n");
    }
    
    /* Shorten */
    ConfWriter_start_short_names();
    if (has_libkern_osatomic_h) {
        ConfWriter_shorten_macro("HAS_LIBKERN_OSATOMIC_H");
    }
    if (has_sys_atomic_h) {
        ConfWriter_shorten_macro("HAS_SYS_ATOMIC_H");
    }
    if (has_intrin_h) {
        ConfWriter_shorten_macro("HAS_INTRIN_H");
    }
    ConfWriter_end_short_names();

    ConfWriter_end_module();
}


/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

