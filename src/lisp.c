/* Lisp parser

   Copyright (c) 2001, 2005, 2008, 2009, 2010 Free Software Foundation, Inc.

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

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "main.h"
#include "extern.h"

/*
 * Zile Lisp functions.
 */

bool
function_exists (const char *name)
{
  bool exists;
  CLUE_SET (L, name, string, name);
  CLUE_DO (L, "exists = usercmd[name] ~= nil");
  CLUE_GET (L, exists, boolean, exists);
  return exists;
}

/* Return function's interactive flag, or -1 if not found. */
int
get_function_interactive (const char *name)
{
  bool i;
  CLUE_SET (L, name, string, name);
  CLUE_DO (L, "i = usercmd[name].interactive");
  CLUE_GET (L, i, boolean, i);
  return i;
  /* FIXME: return f ? f->interactive : -1; */
}

const char *
get_function_doc (const char *name)
{
  const char *doc;
  CLUE_SET (L, name, string, name);
  CLUE_DO (L, "doc = usercmd[name].doc");
  CLUE_GET (L, doc, string, doc);
  return doc;
  /* FIXME: return f ? f->doc : NULL; */
}

le
execute_with_uniarg (bool undo, int uniarg, bool (*forward) (void), bool (*backward) (void))
{
  int uni, ret = true;
  bool (*func) (void) = forward;

  if (backward && uniarg < 0)
    {
      func = backward;
      uniarg = -uniarg;
    }
  if (undo)
    undo_save (UNDO_START_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
  for (uni = 0; ret && uni < uniarg; ++uni)
    ret = func ();
  if (undo)
    undo_save (UNDO_END_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);

  return bool_to_lisp (ret);
}

/*
 * The type of a Zile exported function.
 * `uniarg' is the universal argument, if any, whose presence is
 * indicated by `is_uniarg'.
 */
typedef le (*Function) (long uniarg, bool is_uniarg, le list);

le
execute_function (const char *name, int uniarg, bool is_uniarg, le list)
{
  bool isfunc = false;
  int mp;

  assert (name);
  CLUE_SET (L, name, string, name);
  CLUE_DO (L, "func = usercmd[name] and usercmd[name].func or nil");
  CLUE_GET (L, func, boolean, isfunc);

  if (isfunc)
    {
      Function func;
      CLUE_GET (L, func, lightuserdata, func);
      if (func)
        return func (uniarg, is_uniarg, list);
      else
        {
          bool ret;
          lua_rawgeti (L, LUA_REGISTRYINDEX, list);
          lua_setglobal (L, "branch");
          CLUE_DO (L, "ret = call_zile_command (name, branch)");
          CLUE_GET (L, ret, boolean, ret);
          return ret;
        }
    }
  else
    {
      mp = get_macro (name);
      if (mp != LUA_REFNIL)
        {
          call_macro (mp);
          return leT;
        }
      return leNIL;
    }
}

DEFUN ("execute-extended-command", execute_extended_command)
/*+
Read function name, then read its arguments and call it.
+*/
{
  const char *name;
  astr msg = astr_new ();

  if (lastflag () & FLAG_SET_UNIARG)
    {
      if (lastflag () & FLAG_UNIARG_EMPTY)
        astr_afmt (msg, "C-u ");
      else
        astr_afmt (msg, "%d ", uniarg);
    }
  astr_cat_cstr (msg, "M-x ");

  name = minibuf_read_function_name (astr_cstr (msg));
  astr_delete (msg);
  if (name == NULL)
    return false;

  ok = execute_function (name, uniarg, true, LUA_REFNIL);
  free ((char *) name);
}
END_DEFUN

/*
 * Read a function name from the minibuffer.
 */
static int functions_history = LUA_REFNIL;
const char *
minibuf_read_function_name (const char *fmt)
{
  int cp;

  CLUE_DO (L, "cp = completion_new ()");
  lua_getglobal (L, "cp");
  cp = luaL_ref (L, LUA_REGISTRYINDEX);

  CLUE_DO (L, "for name, func in pairs (usercmd) do if func.interactive then table.insert (cp.completions, name) end end");
  CLUE_DO (L, "add_macros_to_list (cp)");

  return minibuf_vread_completion (fmt, "", cp, functions_history,
                                   "No function name given",
                                   "Undefined function name `%s'");
}

static int
call_zile_c_command (lua_State *L)
{
  le trybranch = LUA_REFNIL;
  const char *keyword;
  int uniarg;
  bool is_uniarg;

  assert (lua_gettop (L) == 4);
  assert (lua_isstring (L, 1));
  keyword = lua_tostring (L, 1);
  uniarg = lua_tointeger (L, 2);
  is_uniarg = lua_toboolean (L, 3);
  trybranch = luaL_ref (L, LUA_REGISTRYINDEX);
  assert (function_exists (keyword));
  lua_pushvalue (L, execute_function (keyword, uniarg, is_uniarg, trybranch));
  luaL_unref (L, LUA_REGISTRYINDEX, trybranch);
  return 1;
}

le leNIL, leT;

void
init_lisp (void)
{
  lua_getglobal (L, "leNIL");
  leNIL = luaL_ref (L, LUA_REGISTRYINDEX);
  lua_getglobal (L, "leT");
  leT = luaL_ref (L, LUA_REGISTRYINDEX);

  lua_getglobal (L, "functions_history");
  functions_history = luaL_ref (L, LUA_REGISTRYINDEX);

  lua_register (L, "call_zile_c_command", call_zile_c_command);

#define X(zile_name, c_name)                            \
  lua_pushlightuserdata (L, F_ ## c_name);              \
  lua_setglobal (L, "ptr");                             \
  CLUE_SET (L, name, string, zile_name);                \
  CLUE_DO (L, "usercmd[name].func = ptr");
#include "tbl_funcs.h"
#undef X
}
