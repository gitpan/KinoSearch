#define CHAZ_USE_SHORT_NAMES

#include <errno.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include "Charmonizer/Core/Util.h"

/* Global verbosity setting. */
int Util_verbosity = 1;

void
Util_write_file(const char *filename, const char *content)
{
    FILE *fh = fopen(filename, "w+");
    size_t content_len = strlen(content);
    if (fh == NULL) {
        Util_die("Couldn't open '%s': %s", filename, strerror(errno));
    }
    fwrite(content, sizeof(char), content_len, fh);
    if (fclose(fh)) {
        Util_die("Error when closing '%s': %s", filename, strerror(errno));
    }
}

char*
Util_slurp_file(const char *file_path, size_t *len_ptr) 
{
    FILE   *const file = fopen(file_path, "r");
    char   *contents;
    size_t  len;
    long    check_val;

    /* Sanity check. */
    if (file == NULL) {
        Util_die("Error opening file '%s': %s", file_path, strerror(errno));
    }

    /* Find length; return NULL if the file has a zero-length. */
    len = Util_flength(file);
    if (len == 0) {
        *len_ptr = 0;
        return NULL;
    }

    /* Allocate memory and read the file. */
    contents = (char*)malloc(len * sizeof(char) + 1);
    if (contents == NULL) {
        Util_die("Out of memory at %d, %s", __FILE__, __LINE__);
    }
    contents[len] = '\0';
    check_val = fread(contents, sizeof(char), len, file);

    /* Weak error check, because CRLF might result in fewer chars read. */
    if (check_val <= 0) {
        Util_die("Tried to read %d characters of '%s', got %d", (int)len,
            file_path, check_val);
    }

    /* Set length pointer for benefit of caller. */
    *len_ptr = check_val;

    /* Clean up. */
    if (fclose(file)) {
        Util_die("Error closing file '%s': %s", file_path, strerror(errno));
    }

    return contents;
}

long 
Util_flength(FILE *f) 
{
    const long bookmark = ftell(f);
    long check_val;
    long len;

    /* Seek to end of file and check length. */
    check_val = fseek(f, 0, SEEK_END);
    if (check_val == -1) { Util_die("fseek error : %s\n", strerror(errno)); }
    len = ftell(f);
    if (len == -1) { Util_die("ftell error : %s\n", strerror(errno)); }

    /* Return to where we were. */
    check_val = fseek(f, bookmark, SEEK_SET);
    if (check_val == -1) { Util_die("fseek error : %s\n", strerror(errno)); }

    return len;
}

void 
Util_die(const char* format, ...) 
{
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    fprintf(stderr, "\n");
    exit(1);
}

void 
Util_warn(const char* format, ...) 
{
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    fprintf(stderr, "\n");
}

int
Util_remove_and_verify(const char *file_path) 
{
    /* Try to remove the file. */
    remove(file_path);

    /* Return what *might* be success or failure. */
    return Util_can_open_file(file_path) ? 0 : 1;
}

int
Util_can_open_file(const char *file_path) 
{
    FILE *garbage_fh;

    /* Use fopen as a portable test for the existence of a file. */
    garbage_fh = fopen(file_path, "r");
    if (garbage_fh == NULL) {
        return 0;
    }
    else {
        fclose(garbage_fh);
        return 1;
    }
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

