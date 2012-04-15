#define CHAZ_USE_SHORT_NAMES

#include "Charmonizer/Core/Util.h"
#include "Charmonizer/Core/ConfWriter.h"
#include "Charmonizer/Core/OperatingSystem.h"
#include "Charmonizer/Core/Compiler.h"
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Static vars. */
static FILE *charmony_fh  = NULL;

void
ConfWriter_init()
{
    return;
}

void
ConfWriter_open_charmony_h(const char *charmony_start)
{
    /* Open the filehandle. */
    charmony_fh = fopen("charmony.h", "w+");
    if (charmony_fh == NULL) {
        Util_die("Can't open 'charmony.h': %s", strerror(errno));
    }

    /* Print supplied text (if any) along with warning, open include guard. */
    if (charmony_start != NULL) {
        fwrite(charmony_start, sizeof(char), strlen(charmony_start), 
            charmony_fh);
    }
    fprintf(charmony_fh,
        "/* Header file auto-generated by Charmonizer. \n"
        " * DO NOT EDIT THIS FILE!!\n"
        " */\n\n"
        "#ifndef H_CHARMONY\n"
        "#define H_CHARMONY 1\n\n"
    );
}

FILE*
ConfWriter_get_charmony_fh(void)
{
    return charmony_fh;
}

void
ConfWriter_clean_up(void)
{
    /* Clean up some temp files. */
    remove("_charm.h");
    OS_remove_exe("_charm_stat");

    /* Write the last bit of charmony.h and close. */
    fprintf(charmony_fh, "#endif /* H_CHARMONY */\n\n");
    if (fclose(charmony_fh)) {
        Util_die("Couldn't close 'charmony.h': %s", strerror(errno));
    }
}

void
ConfWriter_append_conf(const char *fmt, ...)
{
    va_list args;

    va_start(args, fmt);
    vfprintf(charmony_fh, fmt, args);
    va_end(args);
}

void
ConfWriter_start_short_names(void)
{
    ConfWriter_append_conf(
        "\n#if defined(CHY_USE_SHORT_NAMES) "
        "|| defined(CHAZ_USE_SHORT_NAMES)\n"
    );
}

void
ConfWriter_end_short_names(void)
{
    ConfWriter_append_conf("#endif /* USE_SHORT_NAMES */\n");
}

void
ConfWriter_start_module(const char *module_name)
{
    if (chaz_Util_verbosity > 0) {
        printf("Running %s module...\n", module_name);
    }
    ConfWriter_append_conf("\n/* %s */\n", module_name);
}

void
ConfWriter_end_module(void)
{
    ConfWriter_append_conf("\n");
}

void
ConfWriter_shorten_macro(const char *sym)
{
    ConfWriter_append_conf("  #define %s CHY_%s\n", sym, sym); 
}

void
ConfWriter_shorten_typedef(const char *sym)
{
    ConfWriter_append_conf("  #define %s chy_%s\n", sym, sym); 
}

void
ConfWriter_shorten_function(const char *sym)
{
    ConfWriter_append_conf("  #define %s chy_%s\n", sym, sym); 
}

/* Copyright 2006-2011 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

