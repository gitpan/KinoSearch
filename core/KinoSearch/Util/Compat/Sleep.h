#ifndef H_KINO_SLEEP
#define H_KINO_SLEEP

/** Provide a basic sleep() function.
 */

void
kino_Sleep_sleep(unsigned int seconds);

#ifdef KINO_USE_SHORT_NAMES
  #define Sleep_sleep kino_Sleep_sleep
#endif

#endif /* H_KINO_SLEEP */

