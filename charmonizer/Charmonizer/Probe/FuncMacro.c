#define CHAZ_USE_SHORT_NAMES

#include "Charmonizer/Core/ModHandler.h"
#include "Charmonizer/Core/Util.h"
#include "Charmonizer/Probe/FuncMacro.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

/* code for verifying ISO func macro */
static char iso_func_code[] = "\n"
    "    #include \"_charm.h\" \n"
    "    int main() {\n"
    "        Charm_Setup;\n"
    "        printf(\"%s\", __func__);\n"
    "        return 0;\n"
    "    }\n"
    "";

/* code for verifying GNU func macro */
static char gnuc_func_code[] = "\n"
    "    #include \"_charm.h\" \n"
    "    int main() {\n"
    "        Charm_Setup;\n"
    "        printf(\"%s\", __FUNCTION__);\n"
    "        return 0;\n"
    "    }\n"
    "";

/* code for verifying inline keyword */
static char inline_code[] = "\n"
    "    #include \"_charm.h\" \n"
    "    inline int foo() { return 1; }\n"
    "    int main() {\n"
    "        Charm_Setup;\n"
    "        printf(\"%d\", foo());\n"
    "        return 0;\n"
    "    }\n"
    "";


void
chaz_FuncMacro_run(void) 
{
    char *output;
    size_t output_len;
    chaz_bool_t has_funcmac      = false;
    chaz_bool_t has_iso_funcmac  = false;
    chaz_bool_t has_gnuc_funcmac = false;
    chaz_bool_t has_inline       = false;

    START_RUN("FuncMacro");
    
    /* check for ISO func macro */
    output = capture_output(iso_func_code, strlen(iso_func_code), 
        &output_len);
    if (output != NULL && strncmp(output, "main", 4) == 0) {
        has_funcmac     = true;
        has_iso_funcmac = true;
    }
    free(output);

    /* check for GNUC func macro */
    output = capture_output(gnuc_func_code, strlen(gnuc_func_code), 
        &output_len);
    if (output != NULL && strncmp(output, "main", 4) == 0) {
        has_funcmac      = true;
        has_gnuc_funcmac = true;
    }
    free(output);

    /* write out common defines */
    if (has_funcmac) {
        char *macro_text = has_iso_funcmac 
            ? "__func__"
            : "__FUNCTION__";
        append_conf(
			"#define CHY_HAS_FUNC_MACRO\n"
            "#define CHY_FUNC_MACRO %s\n",
            macro_text
        );
    }

    /* write out specific defines */
    if (has_iso_funcmac) {
       append_conf("#define CHY_HAS_ISO_FUNC_MACRO\n");
    }
    if (has_gnuc_funcmac) {
        append_conf("#define CHY_HAS_GNUC_FUNC_MACRO\n");
    }

    /* Check for inline keyword. */
    output = capture_output(inline_code, strlen(inline_code), 
        &output_len);
    if (output != NULL) {
        has_inline = true;
        append_conf("#define CHY_INLINE inline\n");
    }
    else {
        append_conf("#define CHY_INLINE\n");
    }
    free(output);

	/* shorten */
    START_SHORT_NAMES;
    if (has_iso_funcmac) 
        shorten_macro("HAS_ISO_FUNC_MACRO");
    if (has_gnuc_funcmac)
        shorten_macro("HAS_GNUC_FUNC_MACRO");
    if (has_iso_funcmac || has_gnuc_funcmac) {
        shorten_macro("HAS_FUNC_MACRO");
        shorten_macro("FUNC_MACRO");
    }
    shorten_macro("INLINE");
    END_SHORT_NAMES;

    END_RUN;
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

