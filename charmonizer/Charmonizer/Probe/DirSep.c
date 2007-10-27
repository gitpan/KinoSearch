#define CHAZ_USE_SHORT_NAMES

#include "Charmonizer/Core/ModHandler.h"
#include "Charmonizer/Core/Util.h"
#include "Charmonizer/Probe/DirSep.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

static char mkdir_code[] = "\n"
    "    #include \"_charm.h\"\n"
    "    #include <sys/stat.h>\n"
    "    int main () {\n"
    "        Charm_Setup;\n"
    "        if (mkdir(\"_charm_test_dir_orig\", 0777) == 0) {\n"
    "            printf(\"1\");\n"
    "        }\n"
    "        return 0;\n"
    "    }\n"
    "";

void
chaz_DirSep_run(void) 
{
    char        *output;
    size_t       output_len;
    char         dir_sep[3];
    chaz_bool_t  dir_sep_is_valid = false;

    START_RUN("DirSep");

    /* create a directory */
    output = capture_output(mkdir_code, strlen(mkdir_code), &output_len);

    if (output != NULL && (strcmp(output, "1") == 0)) {
        FILE *f;

        /* clean up */
        free(output);

        /* try to create files under the new directory */
        if ( (f = fopen("_charm_test_dir_orig\\backslash", "w")) != NULL)
            fclose(f);
        if ( (f = fopen("_charm_test_dir_orig/slash", "w")) != NULL)
            fclose(f);

        /* rename the directory, and see which file we can get to */
        rename("_charm_test_dir_orig", "_charm_test_dir_mod");
        if ( (f = fopen("_charm_test_dir_mod\\backslash", "r")) != NULL) {
            fclose(f);
            strcpy(dir_sep, "\\\\");
            dir_sep_is_valid = true;
        }
        else if ( (f = fopen("_charm_test_dir_mod/slash", "r")) != NULL) {
            fclose(f);
            strcpy(dir_sep, "/");
            dir_sep_is_valid = true;
        }
    }

    /* clean up - delete all possible files without verifying */
    remove("_charm_test_dir_mod/slash");
    remove("_charm_test_dir_mod\\backslash");
    remove("_charm_test_dir_orig/slash");
    remove("_charm_test_dir_orig\\backslash");
    remove("_charm_test_dir_orig");
    remove("_charm_test_dir_mod");

    if (dir_sep_is_valid) {
        append_conf("#define CHY_DIR_SEP \"%s\"\n", dir_sep);

        /* shorten */
        START_SHORT_NAMES;
        shorten_macro("DIR_SEP");
        END_SHORT_NAMES;
    }

    END_RUN;
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

