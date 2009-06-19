#ifndef H_KINO_DEBUG
#define H_KINO_DEBUG

#include "charmony.h"

/* The Debug module provides multiple levels of debugging verbosity.  Code for
 * debug statements is only compiled "#ifdef KINO_DEBUG" at compile-time.  Some
 * statements will then always print; additional output can be enabled using
 * the environment variable KINO_DEBUG.  Examples:
 * 
 *   KINO_DEBUG=file.C      -> all debug statements in path/file.C
 *   KINO_DEBUG=func        -> all in functions named exactly 'func'
 *   KINO_DEBUG=func*       -> all in functions (or files) starting with 'func' 
 *   KINO_DEBUG=file*       -> all in files (or functions) ending with file*'
 *   KINO_DEBUG=func1,func2 -> either in func1 or in func2
 *   KINO_DEBUG=*           -> just print all debug statements
 * 
 * The wildcard character '*' can only go at the end of an identifier.
*/

/* Private function, used only by the DEBUG macros. 
 */
void
kino_Debug_print_mess(const char *file, int line, const char *func, 
                      const char *pat, ...);

/* Private function, used only by the DEBUG macros. 
 */
int 
kino_Debug_debug_should_print(const char *path, const char *func);

/* Force override in cached value of KINO_DEBUG environment variable.
 */
void
kino_Debug_set_env_cache(char *override);

/* Under KINO_DEBUG, track the number of objects allocated, the number freed,
 * and the number of global objects.  If, after all non-global objects should
 * have been cleaned up, these numbers don't balance out, there's a memory
 * leak somewhere.
 */
extern chy_i32_t kino_Debug_num_allocated;
extern chy_i32_t kino_Debug_num_freed;
extern chy_i32_t kino_Debug_num_globals;

#ifdef KINO_DEBUG

#undef KINO_DEBUG   /* undef prior to redefining the command line argument */
#define KINO_DEBUG_ENABLED 1

#include <stdio.h>
#include <stdlib.h>

/* Unconditionally print debug statement prepending file and line info. 
 */
#define KINO_DEBUG_PRINT(args...)                                         \
    kino_Debug_print_mess(__FILE__, __LINE__, __func__, ##args)

/* Conditionally execute code if debugging enabled via KINO_DEBUG environment
 * variable.
 */
#define KINO_DEBUG_DO(actions)                                            \
    do {                                                                  \
        static int initialized = 0;                                       \
        static int do_it       = 0;                                       \
        if (!initialized) {                                               \
            initialized = 1;                                              \
            do_it = kino_Debug_debug_should_print(__FILE__, __func__);    \
        }                                                                 \
        if (do_it) { actions; }                                           \
    } while (0)

/* Execute code so long as KINO_DEBUG was defined during compilation.
 */
#define KINO_IFDEF_DEBUG(actions) do { actions; } while (0)

/* Conditionally print debug statement depending on KINO_DEBUG env variable.
 */
#define KINO_DEBUG(args...)                                            \
        KINO_DEBUG_DO(KINO_DEBUG_PRINT(args));                  

/* Abort on error if test fails.
 *
 * Note: unlike the system assert(), this ASSERT() is #ifdef KINO_DEBUG.
 */
#define KINO_ASSERT(test , args...)                                    \
    do {                                                               \
        if (!(test)) {                                                 \
            KINO_DEBUG_PRINT("ASSERT FAILED (" #test ")\n" args);      \
            abort();                                                   \
        }                                                              \
    } while (0) 

#elif defined(CHY_HAS_GNUC_VARIADIC_MACROS) /* not KINO_DEBUG */

#undef KINO_DEBUG
#define KINO_DEBUG_ENABLED 0
#define KINO_DEBUG_DO(actions)
#define KINO_IFDEF_DEBUG(actions)
#define KINO_DEBUG_PRINT(args...)
#define KINO_DEBUG(args...)
#define KINO_ASSERT(test, args...)

#else  /* also not KINO_DEBUG */

#undef KINO_DEBUG
#define KINO_DEBUG_ENABLED 0
#define KINO_DEBUG_DO(actions)
#define KINO_IFDEF_DEBUG(actions)
static void KINO_DEBUG_PRINT(char *_ignore_me, ...) { }
static void KINO_DEBUG(char *_ignore_me, ...) { }
static void KINO_ASSERT(int _ignore_me, ...) { }

#endif /* KINO_DEBUG */

#ifdef KINO_USE_SHORT_NAMES
  #define DEBUG_ENABLED             KINO_DEBUG_ENABLED
  #define DEBUG_PRINT               KINO_DEBUG_PRINT
  #define DEBUG_DO                  KINO_DEBUG_DO
  #define IFDEF_DEBUG               KINO_IFDEF_DEBUG
  #define DEBUG                     KINO_DEBUG
  #define ASSERT                    KINO_ASSERT
  #define Debug_print_mess          kino_Debug_print_mess
  #define Debug_debug_should_print  kino_Debug_debug_should_print
  #define Debug_set_env_cache       kino_Debug_set_env_cache
  #define Debug_num_allocated       kino_Debug_num_allocated
  #define Debug_num_freed           kino_Debug_num_freed
  #define Debug_num_globals         kino_Debug_num_globals
#endif

#endif /* H_KINO_DEBUG */

