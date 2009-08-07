#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Util/Json.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Util/Host.h"

bool_t
Json_spew_json(Obj *dump, Folder *folder, const CharBuf *filename)
{
    return (bool_t)Host_callback_i(JSON, "spew_json", 3, 
        ARG_OBJ("dump", dump), ARG_OBJ("folder", folder), 
        ARG_STR("filename", filename));
}

Obj*
Json_slurp_json(Folder *folder, const CharBuf *filename)
{
    return Host_callback_obj(JSON, "slurp_json", 2, 
        ARG_OBJ("folder", folder), ARG_STR("filename", filename));
}

CharBuf*
Json_to_json(Obj *dump)
{
    return Host_callback_str(JSON, "to_json", 1,
        ARG_OBJ("dump", dump));
}

Obj*
Json_from_json(CharBuf *json)
{
    return Host_callback_obj(JSON, "from_json", 1, 
        ARG_STR("json", json));
}

