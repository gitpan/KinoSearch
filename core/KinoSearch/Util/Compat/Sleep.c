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

/********************************* UNIXEN *********************************/
#elif defined(CHY_HAS_UNISTD_H)

#include <unistd.h>

void
kino_Sleep_sleep(unsigned int seconds)
{
    sleep(seconds);
}

#else
  #error "Can't find a known sleep API."
#endif /* OS switch. */

