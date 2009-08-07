#include <string.h>
#include <stdlib.h>

#include "KinoSearch/Util/Compat/DirManip.h"
#include "KinoSearch/Obj/CharBuf.h"
#include "KinoSearch/Obj/Err.h"
#include "KinoSearch/Obj/VArray.h"
#include "KinoSearch/Util/Host.h"

#include <sys/stat.h>

kino_CharBuf*
kino_DirManip_absolutify(const kino_CharBuf *path)
{
   
    return kino_Host_callback_str(KINO_DIRMANIP,
            "absolutify", 1, KINO_ARG_STR("path", path));
}
