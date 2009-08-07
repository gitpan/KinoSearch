#include "KinoSearch/Util/Compat/Sleep.h"
#include "charmony.h"

/********************************* WINDOWS ********************************/
#ifdef CHY_HAS_WINDOWS_H

#include <windows.h>

void
kino_Sleep_sleep(unsigned int seconds)
{
    Sleep(seconds * 1000);
}

void
kino_Sleep_millisleep(unsigned int milliseconds)
{
    Sleep(milliseconds);
}

/********************************* UNIXEN *********************************/
#elif defined(CHY_HAS_UNISTD_H)

#include <unistd.h>

void
kino_Sleep_sleep(unsigned int seconds)
{
    sleep(seconds);
}

void
kino_Sleep_millisleep(unsigned int milliseconds)
{
    unsigned int seconds = milliseconds / 1000;
    milliseconds = milliseconds % 1000;
    sleep(seconds);
    /* TODO: probe for usleep. */
    usleep(milliseconds * 1000);
}

#else
  #error "Can't find a known sleep API."
#endif /* OS switch. */

