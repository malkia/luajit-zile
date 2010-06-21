/* Zile variables handling functions

   Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010 Free Software Foundation, Inc.

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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "main.h"
#include "extern.h"

void
set_variable (const char *var, const char *val)
{
  bool local = false;

  CLUE_SET (L, var, string, var);
  CLUE_DO (L, "islocal = (main_vars[var] or {}).islocal");
  CLUE_GET (L, islocal, boolean, local);
  if (local)
    {
      if (get_buffer_vars (cur_bp ()) == LUA_REFNIL)
        {
          lua_newtable (L);
          set_buffer_vars (cur_bp (), luaL_ref (L, LUA_REGISTRYINDEX));
        }
      lua_rawgeti (L, LUA_REGISTRYINDEX, get_buffer_vars (cur_bp ()));
    }
  else
    lua_getglobal (L, "main_vars");

  lua_getfield (L, -1, var);
  if (!lua_istable (L, -1))
    {
      lua_pop (L, 1);
      lua_newtable (L);
      lua_setfield (L, -2, var);
      lua_getfield (L, -1, var);
    }

  lua_pushstring (L, val);
  lua_setfield (L, -2, "val");

  lua_pop (L, 2);
}

static int
zlua_get_variable (lua_State *L)
{
    const char *var = lua_tostring (L, -1);
    const char *val = get_variable (var);
    lua_pop (L, 1);
    if (val)
      lua_pushstring (L, val);
    else
      lua_pushnil (L);
    return 1;
}

static int
zlua_set_variable (lua_State *L)
{
    const char *var = lua_tostring (L, -2);
    const char *val = lua_tostring (L, -1);
    lua_pop (L, 2);
    set_variable (var, val);
    return 0;
}

void
init_variables (void)
{
  lua_register (L, "get_variable", zlua_get_variable);
  lua_register (L, "set_variable", zlua_set_variable);
}

const char *
get_variable (const char *var)
{
  const char *val;
  CLUE_SET (L, var, string, var);
  CLUE_DO (L, "val = get_variable_bp (cur_bp, var)");
  CLUE_GET (L, val, string, val);
  return val;
}

long
get_variable_number_bp (int bp, const char *var)
{
  long t = 0;
  const char *s;

  lua_rawgeti (L, LUA_REGISTRYINDEX, bp);
  lua_setglobal (L, "bp");
  CLUE_SET (L, var, string, var);
  CLUE_DO (L, "val = get_variable_bp (bp, var)");
  CLUE_GET (L, val, string, s);

  if (s)
    t = strtol (s, NULL, 10);
  /* FIXME: Check result and signal error. */

  return t;
}

long
get_variable_number (const char *var)
{
  return get_variable_number_bp (cur_bp (), var);
}

bool
get_variable_bool (const char *var)
{
  const char *p = get_variable (var);
  if (p != NULL)
    return strcmp (p, "nil") != 0;

  return false;
}

DEFUN_ARGS ("set-variable", set_variable,
            STR_ARG (var)
            STR_ARG (val))
/*+
Set a variable value to the user-specified value.
+*/
{
  STR_INIT (var)
  else
    var = minibuf_read_variable_name ("Set variable: ");
  if (var == NULL)
    return leNIL;
  STR_INIT (val)
  else
    val = minibuf_read (astr_cstr (astr_afmt (astr_new (), "Set %s to value: ", var)), "");
  if (val == NULL)
    ok = FUNCALL (keyboard_quit);

  if (ok == leT)
    set_variable (var, val);

  STR_FREE (var);
  STR_FREE (val);
}
END_DEFUN
