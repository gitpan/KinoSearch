#ifndef H_KINO_SLEEP
#define H_KINO_SLEEP

/** Provide a basic sleep() function.
 */

void
kino_Sleep_sleep(unsigned int seconds);

/** Sleep for 0 - 1000 milliseconds.  
 */
void
kino_Sleep_millisleep(unsigned int milliseconds);

#ifdef KINO_USE_SHORT_NAMES
  #define Sleep_sleep      kino_Sleep_sleep
  #define Sleep_millisleep kino_Sleep_millisleep
#endif

#endif /* H_KINO_SLEEP */

