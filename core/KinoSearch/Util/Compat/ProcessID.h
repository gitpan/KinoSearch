#ifndef H_KINO_PROCESSID
#define H_KINO_PROCESSID

#include "charmony.h"

/* Return the ID for the current process.
 */
int 
kino_PID_getpid(void);

/** Return true if the supplied process ID is associated with an active
 * process.
 */
chy_bool_t
kino_PID_active(int pid);

#ifdef KINO_USE_SHORT_NAMES
  #define PID_getpid kino_PID_getpid
  #define PID_active kino_PID_active
#endif

#endif /* H_KINO_PROCESSID */

