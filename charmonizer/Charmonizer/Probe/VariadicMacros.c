#define CHAZ_USE_SHORT_NAMES

#include "Charmonizer/Core/ModHandler.h"
#include "Charmonizer/Core/Util.h"
#include "Charmonizer/Probe/VariadicMacros.h"
#include <string.h>
#include <stdio.h>


/* code for verifying ISO-style variadic macros */
static char iso_code[] = "\n"
    "    #include \"_charm.h\"\n"
    "    #define ISO_TEST(fmt, ...) \\\n"
    "        printf(fmt, __VA_ARGS__)\n"
    "    int main() {\n"
    "        Charm_Setup;\n"
    "        ISO_TEST(\"%d %d\", 1, 1);\n"
    "        return 0;\n"
    "    }\n"
    "";

/* code for verifying GNU-style variadic macros */
static char gnuc_code[] = "\n"
    "    #include \"_charm.h\"\n"
    "    #define GNU_TEST(fmt, args...) \\\n"
    "        printf(fmt, ##args)\n"
    "    int main() {\n"
    "        Charm_Setup;\n"
    "        GNU_TEST(\"%d %d\", 1, 1);\n"
    "        return 0;\n"
    "    }\n"
    "";

void
chaz_VariadicMacros_run(void) 
{
    char *output;
    size_t output_len;
    chaz_bool_t has_varmacros      = false;
    chaz_bool_t has_iso_varmacros  = false;
    chaz_bool_t has_gnuc_varmacros = false;

    START_RUN("VariadicMacros");

    /* test for ISO-style variadic macros */
    output = capture_output(iso_code, strlen(iso_code), &output_len);
    if (output != NULL) {
        has_varmacros = true;
        has_iso_varmacros = true;
        append_conf("#define CHY_HAS_VARIADIC_MACROS\n");
        append_conf("#define CHY_HAS_ISO_VARIADIC_MACROS\n");
    }

    /* test for GNU-style variadic macros */
    output = capture_output(gnuc_code, strlen(gnuc_code), &output_len);
    if (output != NULL) {
        has_gnuc_varmacros = true;
        if (has_varmacros == false) {
            has_varmacros = true;
            append_conf("#define CHY_HAS_VARIADIC_MACROS\n");
        }
        append_conf("#define CHY_HAS_GNUC_VARIADIC_MACROS\n");
    }

	/* shorten */
    START_SHORT_NAMES;
    if (has_varmacros)
        shorten_macro("HAS_VARIADIC_MACROS");
    if (has_iso_varmacros)
        shorten_macro("HAS_ISO_VARIADIC_MACROS");
    if (has_gnuc_varmacros)
        shorten_macro("HAS_GNUC_VARIADIC_MACROS");
    END_SHORT_NAMES;

    END_RUN;
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

