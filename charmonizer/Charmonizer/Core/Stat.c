#define CHAZ_USE_SHORT_NAMES

#include <stdlib.h>
#include <string.h>

#include "Charmonizer/Core/Stat.h"

#include "Charmonizer/Core/Compiler.h"
#include "Charmonizer/Core/HeadCheck.h"
#include "Charmonizer/Core/ModHandler.h"
#include "Charmonizer/Core/OperSys.h"
#include "Charmonizer/Core/Util.h"

static chaz_bool_t initialized    = false;
static chaz_bool_t stat_available = false;

/* lazily compile _charm_stat */
static void
init();

void
chaz_Stat_stat(const char *filepath, chaz_Stat *target)
{
    char *stat_output;
    size_t output_len;

    /* failsafe */
    target->valid = false;

    /* lazy init */
    if (!initialized)
        init();

    /* bail out if we didn't succeed in compiling/using _charm_stat */
    if (!stat_available)
        return;

    /* run _charm_stat */
    remove_and_verify("_charm_statout");
    os->run_local(os, "_charm_stat ", filepath, NULL);
    stat_output = slurp_file("_charm_statout", &output_len);
    remove_and_verify("_charm_statout");

    /* parse the output of _charm_stat and store vars in Stat struct */
    if (stat_output != NULL) {
        char *end_ptr = stat_output;
        target->size     = strtol(stat_output, &end_ptr, 10);
        stat_output      = end_ptr;
        target->blocks   = strtol(stat_output, &end_ptr, 10);
        target->valid = true;
    }

    return;
}

/* source code for the _charm_stat utility */
static char charm_stat_code[] = "\n"
    "    #include <stdio.h>\n"
    "    #include <sys/stat.h>\n"
    "    int main(int argc, char **argv) {\n"
    "        FILE *out_fh = fopen(\"_charm_statout\", \"w+\");\n"
    "        struct stat st;\n"
    "        if (argc != 2)\n"
    "            return 1;\n"
    "        if (stat(argv[1], &st) == -1)\n"
    "            return 2;\n"
    "        fprintf(out_fh, \"%ld %ld\\n\", (long)st.st_size, (long)st.st_blocks);\n"
    "        return 0;\n"
    "    }\n"
    "";

static void
init()
{
    /* only try this once */
    initialized = true;
    if (verbosity)
        printf("Attempting to compile _charm_stat utility...\n");

    /* bail if sys/stat.h isn't available */
    if (!check_header("sys/stat.h"))
        return;

    /* if the compile succeeds, open up for business */
    stat_available = compiler->compile_exe(compiler, "_charm_stat.c",
        "_charm_stat", charm_stat_code, strlen(charm_stat_code));
    remove("_charm_stat.c");
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

