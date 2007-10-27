#define CHAZ_USE_SHORT_NAMES

#include "Charmonizer/Core/HeadCheck.h"
#include "Charmonizer/Core/ModHandler.h"
#include "Charmonizer/Core/Stat.h"
#include "Charmonizer/Core/Util.h"
#include "Charmonizer/Probe/LargeFiles.h"
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

/* sets of symbols which might provide large file support */
typedef struct off64_combo {
    const char *includes;
    const char *ftell_command;
    const char *fseek_command;
    const char *offset64_type;
} off64_combo;
static off64_combo off64_combos[] = {
    { "#include <sys/types.h>\n", "ftello64", "fseeko64", "off64_t" },
    { "#include <sys/types.h>\n", "ftello", "fseeko", "off_t" },
    { "", "ftell","fseek", "long" },
    { "", "_ftelli64","_fseeki64", "__int64" },
    { NULL, NULL, NULL, NULL }
};

/* Check what name 64-bit ftell, fseek go by.
 */
static chaz_bool_t
probe_off64(off64_combo *combo);

/* Determine whether we can use sparse files.
 */
static chaz_bool_t 
check_sparse_files();

/* Helper for check_sparse_files().  
 */
static void
test_sparse_file(long offset, Stat *st);

/* See if trying to write a 5 GB file in a subprocess bombs out.  If it
 * doesn't, then the test suite can safely verify large file support.
 */
static chaz_bool_t
can_create_big_files();

static char* code_buf = NULL;
static size_t code_buf_len = 0;

/* vars for holding lfs commands, once they're discovered */
static char fseek_command[10];
static char ftell_command[10];
static char off64_type[10];

void
chaz_LargeFiles_run(void) 
{
    chaz_bool_t success = false;
    unsigned i;

    START_RUN("LargeFiles");

    /* see if off64_t and friends exist or have synonyms */
    for (i = 0; off64_combos[i].includes != NULL; i++) {
        off64_combo combo = off64_combos[i];
        success = probe_off64(&combo);
        if (success) {
            strcpy(fseek_command, combo.fseek_command);
            strcpy(ftell_command, combo.ftell_command);
            strcpy(off64_type, combo.offset64_type);
            break;
        }
    }

    /* write the affirmations/definitions */
    if (success) {
        append_conf("#define CHY_HAS_LARGE_FILE_SUPPORT\n");
        /* alias these only if they're not already provided and correct */
        if (strcmp(off64_type, "off64_t") != 0) {
            append_conf("#define chy_off64_t %s\n",  off64_type);
            append_conf("#define chy_ftello64 %s\n", ftell_command);
            append_conf("#define chy_fseeko64 %s\n", fseek_command);
        }
    }

    /* check for sparse files */
    if (check_sparse_files()) {
        append_conf("#define CHAZ_HAS_SPARSE_FILES\n");
        /* see if we can create a 5 GB file without crashing */
        if (success && can_create_big_files())
            append_conf("#define CHAZ_CAN_CREATE_BIG_FILES\n");
    }
    else {
        append_conf("#define CHAZ_NO_SPARSE_FILES\n");
    }

    /* short names */
    if (success) {
        START_SHORT_NAMES;
        shorten_macro("HAS_LARGE_FILE_SUPPORT");

        /* alias these only if they're not already provided and correct */
        if (strcmp(off64_type, "off64_t") != 0) {
            shorten_typedef("off64_t");
            shorten_function("ftello64");
            shorten_function("fseeko64");
        }
        END_SHORT_NAMES;
    }
    
    free(code_buf);
    END_RUN;
}

/* code for checking ftello64 and friends */
static char off64_code[] = "\n"
    "    %s\n"
    "    #include \"_charm.h\"\n"
    "    int main() {\n"
    "        %s foo;\n"
    "        Charm_Setup;\n"
    "        printf(\"%%d\", (int)sizeof(%s));\n"
    "        foo = %s(stdout);\n"
    "        %s(stdout, 0, SEEK_SET);\n"
    "        return 0;\n"
    "    }\n"
    "";


static chaz_bool_t
probe_off64(off64_combo *combo)
{
    char *output = NULL;
    size_t output_len;
    size_t needed = sizeof(off64_code) + (2 * strlen(combo->offset64_type)) 
        + strlen(combo->ftell_command) + strlen(combo->fseek_command) + 20;
    chaz_bool_t success = false;

    /* allocate buffer as necessary and prepare the source code */
    if (code_buf_len < needed) {
        code_buf = (char*)realloc(code_buf, needed);
        code_buf_len = needed;
    }
    sprintf(code_buf, off64_code, combo->includes, combo->offset64_type, 
        combo->offset64_type, combo->ftell_command, combo->fseek_command);

    /* verify compilation and that the offset type has 8 bytes */
    output = capture_output(code_buf, strlen(code_buf), 
        &output_len);
    if (output != NULL) {
        long size = strtol(output, NULL, 10);
        if (size == 8)
            success = true;
        free(output);
    }

    return success;
}

static chaz_bool_t 
check_sparse_files()
{
    Stat st_a, st_b;

    /* bail out if we can't stat() a file */
    if (!check_header("sys/stat.h"))
        return false;

    /* write and stat a 1 MB file and a 2 MB file, both of them sparse */
    test_sparse_file(1000000, &st_a);
    test_sparse_file(2000000, &st_b);
    if (!(st_a.valid && st_b.valid))
        return false;
    if (st_a.size != 1000001)
        die ("Expected size of 1000001 but got %ld", (long)st_a.size);
    if (st_b.size != 2000001)
        die ("Expected size of 2000001 but got %ld", (long)st_b.size);

    /* see if two files with very different lengths have the same block size */
    if (st_a.blocks == st_b.blocks)
        return true;
    else
        return false;
} 

static void
test_sparse_file(long offset, Stat *st)
{
    FILE *sparse_fh;

    /* make sure the file's not there, then open */
    remove_and_verify("_charm_sparse");
    if ( (sparse_fh = fopen("_charm_sparse", "w+")) == NULL )
        die("Couldn't open file '_charm_sparse'");

    /* seek fh to [offset], write a byte, close file */
    if ( (fseek(sparse_fh, offset, SEEK_SET)) == -1)
        die("seek failed: %s", strerror(errno));
    if ( (fprintf(sparse_fh, "X")) != 1 )
        die("fprintf failed");
    if (fclose(sparse_fh))
        die("Error closing file '_charm_sparse': %s", strerror(errno));

    /* stat the file */
    Stat_stat("_charm_sparse", st);

    remove("_charm_sparse");
}

/* open a file, seek to a loc, print a char, and communicate success */
static char create_bigfile_code_a[] = "\n"
    "    #include \"_charm.h\"\n"
    "    int main() {\n"
    "        FILE *fh = fopen(\"_charm_large_file_test\", \"w+\");\n"
    "        int check_seek;\n"
    "        Charm_Setup;\n"
    "        /* bail unless seek succeeds */\n"
    "        check_seek = \n"
    "";

static char create_bigfile_code_b[] = "\n"
    "            (fh, 5000000000, SEEK_SET);\n"
    "        if (check_seek == -1)\n"
    "            exit(1);\n"
    "        /* bail unless we write successfully */\n"
    "        if (fprintf(fh, \"X\") != 1)\n"
    "            exit(1);\n"
    "        if (fclose(fh))\n"
    "            exit(1);\n"
    "        /* communicate success to Charmonizer */\n"
    "        printf(\"1\");\n"
    "        return 0;\n"
    "    }\n"
    "";

static chaz_bool_t
can_create_big_files()
{
    char *output;
    size_t output_len;
    FILE *truncating_fh;

    /* concat the source strings, compile the file, capture output */
    code_buf_len = join_strings(&code_buf, code_buf_len,
        create_bigfile_code_a, fseek_command, create_bigfile_code_b, NULL);

    output = capture_output(code_buf, code_buf_len, &output_len);

    /* truncate, just in case the call to remove fails */
    truncating_fh = fopen("_charm_large_file_test", "w");
    if (truncating_fh != NULL)
        fclose(truncating_fh);
    remove_and_verify("_charm_large_file_test");

    /* return true if the test app made it to the finish line */
    return output == NULL ? false : true;
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

