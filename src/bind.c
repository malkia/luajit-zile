/* Key bindings and extended commands

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

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "main.h"
#include "extern.h"

/*--------------------------------------------------------------------------
 * Key binding.
 *--------------------------------------------------------------------------*/

static bool
self_insert_command (void)
{
  int ret = true;
  /* Mask out ~KBD_CTRL to allow control sequences to be themselves. */
  int key;
  CLUE_DO (L, "key = lastkey ()");
  CLUE_GET (L, key, integer, key);
  key &= ~KBD_CTRL;
  deactivate_mark ();
  if (key <= 0xff)
    {
      if (isspace (key) && get_buffer_autofill (cur_bp ()) &&
          get_goalc () > (size_t) get_variable_number ("fill-column"))
        fill_break_line ();
      CLUE_SET (L, key, integer, key);
      CLUE_DO (L, "insert_char (string.char (key))");
    }
  else
    {
      CLUE_DO (L, "ding ()");
      ret = false;
    }

  return ret;
}

DEFUN ("self-insert-command", self_insert_command)
/*+
Insert the character you type.
Whichever character you type to run this command is inserted.
+*/
{
  ok = execute_with_uniarg (true, uniarg, self_insert_command, NULL);
}
END_DEFUN

const char *
last_command (void)
{
  const char *s;
  lua_getglobal (L, "_last_command");
  s = lua_tostring (L, -1);
  if (s)
    s = xstrdup (s);
  else
    s = "";
  lua_pop (L, 1);
  return s;
}

void
set_this_command (const char * cmd)
{
  lua_pushstring (L, cmd);
  lua_setglobal (L, "_this_command");
}

DEFUN_ARGS ("global-set-key", global_set_key,
            STR_ARG (keystr)
            STR_ARG (name))
/*+
Bind a command to a key sequence.
Read key sequence and function name, and bind the function to the key
sequence.
+*/
{
  int keys;

  STR_INIT (keystr);
  if (keystr != NULL)
    {
      CLUE_SET (L, keystr, string, keystr);
      CLUE_DO (L, "keys = keystrtovec (keystr)");
      lua_getglobal (L, "keys");
      keys = luaL_ref (L, LUA_REGISTRYINDEX);
      if (keys == LUA_REFNIL)
        {
          minibuf_error ("Key sequence %s is invalid", keystr);
          return leNIL;
        }
    }
  else
    {
      const char *s;

      minibuf_write ("Set key globally: ");
      CLUE_DO (L, "keys = get_key_sequence ()");
      CLUE_DO (L, "s = keyvectostr (keys)");
      CLUE_GET (L, s, string, s);
      keystr = xstrdup (s);
    }

  STR_INIT (name)
  else
    name = minibuf_read_function_name (astr_cstr (astr_afmt (astr_new(), "Set key %s to command: ", keystr)));
  if (name == NULL)
    return leNIL;

  if (!function_exists (name)) /* Possible if called non-interactively */
    {
      minibuf_error ("No such function `%s'", name);
      return leNIL;
    }
  lua_rawgeti (L, LUA_REGISTRYINDEX, keys);
  lua_setglobal (L, "keys");
  CLUE_SET (L, name, string, name);
  CLUE_DO (L, "root_bindings[keys] = name");

  luaL_unref (L, LUA_REGISTRYINDEX, keys);
  STR_FREE (keystr);
  STR_FREE (name);
}
END_DEFUN
