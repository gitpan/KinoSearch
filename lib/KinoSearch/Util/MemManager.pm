package KinoSearch::Util::MemManager;

1;

__END__

__H__

#ifndef H_KINO_MEM_MANAGER
#define H_KINO_MEM_MANAGER 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchUtilCarp.h"

/* Set this to 1 to enable debugging.  */
#define KINO_MEM_LEAK_DEBUG 0

#if KINO_MEM_LEAK_DEBUG
    #define Kino_New(x,v,n,t) \
        (v = (t*)Kino_New_wrapper(x,(n*sizeof(t))))
    #define Kino_Newz(x,v,n,t) \
        (v = (t*)Kino_Newz_wrapper(x,(n*sizeof(t))))
    #define Kino_Renew(v,n,t) \
        (v = (t*)Kino_Renew_wrapper(v, n*sizeof(t)))
    #define Kino_Safefree(x) \
        Kino_Safefree_wrapper(x)
    #define Kino_savepvn(p,n) \
        Kino_savepvn_wrapper(p,n)
#else
    #define Kino_New(x,v,n,t) New(x,v,n,t)
    #define Kino_Newz(x,v,n,t) Newz(x,v,n,t)
    #define Kino_Renew(v,n,t) Renew(v,n,t)
    #define Kino_Safefree(v) Safefree(v)
    #define Kino_savepvn(p,n) savepvn(p,n)
#endif

void* Kino_New_wrapper(int, size_t);
void* Kino_Newz_wrapper(int, size_t);
void* Kino_Renew_wrapper(void*, size_t);
void  Kino_Safefree_wrapper(void*);
char* Kino_savepvn_wrapper(const char*, I32);

#endif /* include guard */

__C__

#include "KinoSearchUtilMemManager.h"

void*
Kino_New_wrapper(int x, size_t num) {
    void* ptr;
    ptr = malloc(num); 
    return ptr;
}

void*
Kino_Newz_wrapper(int x, size_t num) {
    char* ptr;
    ptr = (char*)malloc(num); 
    memset(ptr, 0, num);
    return (void*)ptr;
}

void*
Kino_Renew_wrapper(void* ptr, size_t num) {
    void* new_ptr;
    new_ptr = realloc(ptr, num);
    return new_ptr;
}

void
Kino_Safefree_wrapper(void* ptr) {
    /* Safefree(ptr); */
    free(ptr);
}

char* 
Kino_savepvn_wrapper(const char* pv, I32 len) {
    char* ptr;
    ptr = (char*)malloc(len + 1);
    if (ptr == NULL) 
        Kino_confess("Out of memory");
    ptr[len] = '\0';
    memcpy(ptr, pv, len);
    return ptr;
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Util::MemManager - wrappers which aid memory debugging

=head1 DESCRIPTION

In normal mode, the C functions in this module are macro aliases for Perl's
memory management tools.  In debug mode, memory management passes through
local functions which make hunting down bugs with Valgrind easier.

No Perl interface.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.161.

=end devdocs
=cut
