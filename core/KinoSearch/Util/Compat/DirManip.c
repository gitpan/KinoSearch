#define C_KINO_DIRMANIP
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <sys/stat.h>

#include "KinoSearch/Util/Compat/DirManip.h"
#include "KinoSearch/Obj/CharBuf.h"
#include "KinoSearch/Obj/Err.h"
#include "KinoSearch/Obj/VArray.h"

#ifdef CHY_HAS_SYS_TYPES_H
  #include <sys/types.h>
#endif

/* For rmdir, (hard) link. */
#ifdef CHY_HAS_UNISTD_H
  #include <unistd.h>
#endif

/* For mkdir. */
#ifdef CHY_HAS_DIRECT_H
  #include <direct.h>
#endif

static void
S_add_to_file_list(kino_VArray *list, kino_CharBuf *path, 
                   kino_CharBuf *prefix, chy_bool_t recurse);

chy_bool_t
kino_DirManip_dir_ok(const kino_CharBuf *path)
{
    struct stat sb;
    if (stat((char*)Kino_CB_Get_Ptr8(path), &sb) != -1) {
        if (sb.st_mode & S_IFDIR) return true;
    }
    return false;
}

void
kino_DirManip_create_dir(const kino_CharBuf *path)
{
    if(-1 == chy_makedir((char*)Kino_CB_Get_Ptr8(path), 0777)) {
        KINO_THROW(KINO_ERR, "Couldn't create directory %o", path);
    }
}

chy_bool_t
kino_DirManip_delete(const kino_CharBuf *path)
{
    char *path_ptr = (char*)Kino_CB_Get_Ptr8(path);
#ifdef CHY_REMOVE_ZAPS_DIRS
    return !remove(path_ptr);
#else 
    return kino_DirManip_dir_ok(path)
        ? !rmdir(path_ptr) 
        : !remove(path_ptr); 
#endif
}

kino_VArray*
kino_DirManip_list_files(const kino_CharBuf *path)
{
    kino_VArray *list = NULL;
    if (kino_DirManip_dir_ok(path)) {
        kino_CharBuf *path_copy = Kino_CB_Clone(path);
        kino_CharBuf *prefix = kino_CB_new_from_trusted_utf8("", 0);
        list = kino_VA_new(0);
        S_add_to_file_list(list, path_copy, prefix, true);
        KINO_DECREF(path_copy);
        KINO_DECREF(prefix);
    }
    return list;
}

static chy_bool_t
S_is_updir(const char *name, size_t len)
{
    if (   (len == 1 && strncmp(".", name, len) == 0)
        || (len == 2 && strncmp("..", name, len) == 0)
    ) {
        return true;
    }
    return false;
}

/********************************** UNIXEN *********************************/
#ifdef CHY_HAS_DIRENT_H

#include <dirent.h>

static CHY_INLINE chy_bool_t
SI_entry_is_dir(kino_CharBuf **fullpath, kino_CharBuf *path, 
                kino_CharBuf *prefix, struct dirent *entry)
{
    #ifdef CHY_HAS_DIRENT_D_TYPE
        CHY_UNUSED_VAR(fullpath);
        CHY_UNUSED_VAR(path);
        CHY_UNUSED_VAR(prefix);
        return entry->d_type == DT_DIR ? true : false;
    #else 
        /* Solaris struct dirent may not have a d_type member. :( */
        if (!*fullpath) { 
            *fullpath = kino_CB_new(100);
        }
        kino_CB_setf(*fullpath, "%o%s%o%s%s", path, CHY_DIR_SEP, prefix, 
            CHY_DIR_SEP, entry->d_name);
        return kino_DirManip_dir_ok(*fullpath);
    #endif
}

static void
S_add_to_file_list(kino_VArray *list, kino_CharBuf *path, 
                   kino_CharBuf *prefix, chy_bool_t recurse)
{
    char *path_ptr = (char*)Kino_CB_Get_Ptr8(path);
    DIR *dirhandle = opendir(path_ptr);
    struct dirent *entry;
    size_t orig_path_size   = Kino_CB_Get_Size(path);
    size_t orig_prefix_size = Kino_CB_Get_Size(prefix);
    kino_CharBuf *fullpath = NULL;

    while (NULL != (entry = readdir(dirhandle))) {
        #ifdef CHY_HAS_DIRENT_D_NAMLEN
        size_t len = entry->d_namlen;
        #else
        size_t len = strlen(entry->d_name);
        #endif

        if (!S_is_updir(entry->d_name, len)) {
            kino_CharBuf *relpath 
                = kino_CB_newf("%o%s", prefix, entry->d_name);
            if (Kino_VA_Get_Size(list) % 10 == 0) {
                Kino_VA_Grow(list, Kino_VA_Get_Size(list) + 10);
            }
            Kino_VA_Push(list, (kino_Obj*)relpath);

            if (recurse && SI_entry_is_dir(&fullpath, path, prefix, entry)) {
                kino_CB_catf(path,   "%s%s", CHY_DIR_SEP, entry->d_name);
                kino_CB_catf(prefix, "%s/", entry->d_name);
                S_add_to_file_list(list, path, prefix, true); /* recurse */
                Kino_CB_Set_Size(path, orig_path_size);
                Kino_CB_Set_Size(prefix, orig_prefix_size);
            }
        }
    }

    if (closedir(dirhandle) == -1) {
        KINO_THROW(KINO_ERR, "Error closing dirhandle: %s", strerror(errno));
    }

    KINO_DECREF(fullpath);
}

/********************************** Windows ********************************/
#elif defined(CHY_HAS_WINDOWS_H)

#include <windows.h>

static void
S_add_to_file_list(kino_VArray *list, kino_CharBuf *path, 
                   kino_CharBuf *prefix, chy_bool_t recurse)
{
    char *path_ptr          = (char*)Kino_CB_Get_Ptr8(path);
    size_t orig_path_size   = Kino_CB_Get_Size(path);
    size_t orig_prefix_size = Kino_CB_Get_Size(prefix);
    HANDLE dirhandle = INVALID_HANDLE_VALUE;
    WIN32_FIND_DATA find_data;
    char search_string[MAX_PATH + 1];

    if (orig_path_size >= MAX_PATH - 2) {
        /* Deal with Windows ceiling on file path lengths. */
        KINO_THROW(KINO_ERR, "directory path is too long: %o", path);
    }
    else {
        /* Append trailing wildcard so Windows lists dir contents. */
        char *path_ptr = search_string;
        memcpy(path_ptr, (char*)Kino_CB_Get_Ptr8(path), orig_path_size);
        memcpy(path_ptr + orig_path_size, "\\*\0", 3);
    }

    dirhandle = FindFirstFile(search_string, &find_data);
    if (INVALID_HANDLE_VALUE == dirhandle) {
        /* Directory inaccessible or doesn't exist. */
        return; 
    } 
    else {
        do {
            size_t len = strlen(find_data.cFileName);
            if (!S_is_updir(find_data.cFileName, len)) {
                kino_CharBuf *relpath 
                    = kino_CB_newf("%o%s", prefix, find_data.cFileName);
                if (Kino_VA_Get_Size(list) % 10 == 0) {
                    Kino_VA_Grow(list, Kino_VA_Get_Size(list) + 10);
                }
                Kino_VA_Push(list, (kino_Obj*)relpath);
                if (   recurse 
                    && (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
                ) {
                    kino_CB_catf(path, "%s%s", CHY_DIR_SEP, 
                        find_data.cFileName);
                    kino_CB_catf(prefix, "%s/", find_data.cFileName);
                    S_add_to_file_list(list, path, prefix, true); 
                    Kino_CB_Set_Size(path, orig_path_size);
                    Kino_CB_Set_Size(prefix, orig_prefix_size);
                }
            }
        } while (FindNextFile(dirhandle, &find_data) != 0);

        if (GetLastError() != ERROR_NO_MORE_FILES) {
            KINO_THROW(KINO_ERR, "Error while traversing directory: %u32",
                (chy_u32_t)GetLastError());
        }
        if (!FindClose(dirhandle)) {
            KINO_THROW(KINO_ERR, "Error while closing directory: %u32", 
                (chy_u32_t)GetLastError());
        }

    }

}
#endif /* CHY_HAS_DIRENT_H vs. CHY_HAS_WINDOWS_H */

chy_bool_t
kino_DirManip_hard_link(const kino_CharBuf *source, 
                        const kino_CharBuf *target)
{
    char *from = (char*)Kino_CB_Get_Ptr8(source);
    char *to   = (char*)Kino_CB_Get_Ptr8(target);
#ifdef CHY_HAS_UNISTD_H
    return !link(from, to);
#elif defined(CHY_HAS_WINDOWS_H)
    return !!CreateHardLink(to, from, NULL);
#endif
}

