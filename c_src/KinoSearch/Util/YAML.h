#ifndef H_KINO_YAML
#define H_KINO_YAML 1

#include "charmony.h"

struct kino_Obj;
struct kino_ByteBuf;

/* Encode a yaml string from a complex data structure.
 */
struct kino_ByteBuf*
kino_YAML_encode_yaml(struct kino_Obj *obj);

/* Decode a yaml string and return a data structure made of Hashes, Arrays,
 * and ByteBufs.
 */
struct kino_Obj*
kino_YAML_parse_yaml(const struct kino_ByteBuf *input);

#ifdef KINO_USE_SHORT_NAMES
  #define YAML_encode_yaml            kino_YAML_encode_yaml
  #define YAML_parse_yaml             kino_YAML_parse_yaml
#endif 

#endif /* H_KINO_YAML */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

