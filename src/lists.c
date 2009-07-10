/* Lisp lists

   Copyright (c) 2008, 2009 Free Software Foundation, Inc.

   This file is part of GNU Zile.

   GNU Zile is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   GNU Zile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GNU Zile; see the file COPYING.  If not, write to the
   Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
   MA 02111-1301, USA.  */

#include "config.h"

#include <stdlib.h>

#include "main.h"
#include "extern.h"

#define LIST_GETTER(cty, lty, field)            \
  cty                                           \
  get_lists_ ## field (const le p)              \
  {                                             \
    cty ret;                                    \
    lua_rawgeti (L, LUA_REGISTRYINDEX, p);      \
    lua_getfield (L, -1, #field);               \
    ret = lua_to ## lty (L, -1);                \
    lua_pop (L, 2);                             \
    return ret;                                 \
  }                                             \

#define LIST_TABLE_GETTER(field)                \
  int                                           \
  get_lists_ ## field (const le p)              \
  {                                             \
    int ret = LUA_REFNIL;                        \
    lua_rawgeti (L, LUA_REGISTRYINDEX, p);      \
    lua_getfield (L, -1, #field);               \
    if (lua_istable (L, -1))                    \
      ret = luaL_ref (L, LUA_REGISTRYINDEX);    \
    lua_pop (L, 1);                             \
    return ret;                                 \
  }                                             \

#define FIELD(cty, lty, field)         \
  LIST_GETTER (cty, lty, field)
#define TABLE_FIELD(field)                      \
  LIST_TABLE_GETTER (field)

#include "list_fields.h"
#undef FIELD
