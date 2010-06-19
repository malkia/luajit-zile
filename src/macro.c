/* Macro facility functions

   Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2008, 2009, 2010 Free Software Foundation, Inc.

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
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "main.h"
#include "extern.h"


#define FIELD(cty, lty, field)                   \
  static LUA_GETTER (macro, cty, lty, field)     \
  static LUA_SETTER (macro, cty, lty, field)
#define TABLE_FIELD(field)                             \
  static LUA_TABLE_GETTER (macro, field)               \
  static LUA_TABLE_SETTER (macro, field)

#include "macro.h"
#undef FIELD
#undef TABLE_FIELD


static int cur_mp, cmd_mp = LUA_REFNIL;

static int
macro_new (void)
{
  CLUE_DO (L, "mp = {keys = {}}");
  lua_getglobal (L, "mp");
  return luaL_ref (L, LUA_REGISTRYINDEX);
}

static void
add_macro_key (int mp, size_t key)
{
  lua_rawgeti (L, LUA_REGISTRYINDEX, get_macro_keys (mp));
  lua_setglobal (L, "keys");
  CLUE_SET (L, key, integer, key);
  CLUE_DO (L, "table.insert (keys, key)");
}

static void
remove_macro_key (int mp)
{
  lua_rawgeti (L, LUA_REGISTRYINDEX, get_macro_keys (mp));
  lua_setglobal (L, "keys");
  CLUE_DO (L, "table.remove (keys)");
}

static void
append_key_list (int to, int from)
{
  lua_rawgeti (L, LUA_REGISTRYINDEX, get_macro_keys (to));
  lua_setglobal (L, "to");
  lua_rawgeti (L, LUA_REGISTRYINDEX, get_macro_keys (from));
  lua_setglobal (L, "from");
  CLUE_DO (L, "to = list.concat (to, from)");
}

void
add_cmd_to_macro (void)
{
  assert (cmd_mp);
  append_key_list (cur_mp, cmd_mp);
  cmd_mp = LUA_REFNIL;
}

void
add_key_to_cmd (size_t key)
{
  if (cmd_mp == LUA_REFNIL)
    cmd_mp = macro_new ();

  add_macro_key (cmd_mp, key);
}

void
remove_key_from_cmd (void)
{
  assert (cmd_mp);
  remove_macro_key (cmd_mp);
}

DEFUN ("start-kbd-macro", start_kbd_macro)
/*+
Record subsequent keyboard input, defining a keyboard macro.
The commands are recorded even as they are executed.
Use @kbd{C-x )} to finish recording and make the macro available.
Use @kbd{M-x name-last-kbd-macro} to give it a permanent name.
+*/
{
  if (thisflag () & FLAG_DEFINING_MACRO)
    {
      minibuf_error ("Already defining a keyboard macro");
      return leNIL;
    }

  if (cur_mp)
    CLUE_DO (L, "cancel_kbd_macro ()");

  minibuf_write ("Defining keyboard macro...");

  set_thisflag (thisflag () | FLAG_DEFINING_MACRO);
  cur_mp = macro_new ();
}
END_DEFUN

DEFUN ("end-kbd-macro", end_kbd_macro)
/*+
Finish defining a keyboard macro.
The definition was started by @kbd{C-x (}.
The macro is now available for use via @kbd{C-x e}.
+*/
{
  if (!(thisflag () & FLAG_DEFINING_MACRO))
    {
      minibuf_error ("Not defining a keyboard macro");
      return leNIL;
    }

  set_thisflag (thisflag () & ~FLAG_DEFINING_MACRO);
}
END_DEFUN

DEFUN ("name-last-kbd-macro", name_last_kbd_macro)
/*+
Assign a name to the last keyboard macro defined.
Argument SYMBOL is the name to define.
The symbol's function definition becomes the keyboard macro string.
Such a \"function\" cannot be called from Lisp, but it is a valid editor command.
+*/
{
  int mp;
  char *ms = minibuf_read ("Name for last kbd macro: ", "");

  if (ms == NULL)
    {
      minibuf_error ("No command name given");
      return leNIL;
    }

  if (cur_mp == LUA_REFNIL)
    {
      minibuf_error ("No keyboard macro defined");
      return leNIL;
    }

  mp = get_macro (ms);
  /* If a macro with this name already exists, update its key list */
  if (mp == LUA_REFNIL)
    {
      int head_mp;
      /* Add a new macro to the list */
      mp = macro_new ();
      lua_getglobal (L, "head_mp");
      head_mp = luaL_ref (L, LUA_REGISTRYINDEX);
      set_macro_next (mp, head_mp);
      set_macro_name (mp, xstrdup (ms));
      lua_rawgeti (L, LUA_REGISTRYINDEX, mp);
      lua_setglobal (L, "head_mp");
    }

  /* Copy the keystrokes from cur_mp. */
  append_key_list (mp, cur_mp);

  free(ms);
}
END_DEFUN

void
call_macro (int mp)
{
  assert (mp != LUA_REFNIL);
  assert (get_macro_keys (mp) != LUA_REFNIL);
  lua_rawgeti (L, LUA_REGISTRYINDEX, get_macro_keys (mp));
  lua_setglobal (L, "keys");
  CLUE_DO (L, "process_keys (keys)");
}

DEFUN ("call-last-kbd-macro", call_last_kbd_macro)
/*+
Call the last keyboard macro that you defined with @kbd{C-x (}.
A prefix argument serves as a repeat count.

To make a macro permanent so you can call it even after
defining others, use @kbd{M-x name-last-kbd-macro}.
+*/
{
  int uni;

  if (cur_mp == LUA_REFNIL)
    {
      minibuf_error ("No kbd macro has been defined");
      return leNIL;
    }

  undo_save (UNDO_START_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
  for (uni = 0; uni < uniarg; ++uni)
    call_macro (cur_mp);
  undo_save (UNDO_END_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
}
END_DEFUN

DEFUN_NONINTERACTIVE_ARGS ("execute-kbd-macro", execute_kbd_macro,
                   STR_ARG (keystr))
/*+
Execute macro as string of editor command characters.
+*/
{
  STR_INIT (keystr);
  CLUE_SET (L, keystr, string, keystr);
  CLUE_DO (L, "keys = keystrtovec (keystr); keys_ok = keys ~= nil");
  {
    bool keys_ok;
    CLUE_GET (L, keys_ok, boolean, keys_ok);
    if (keys_ok)
      CLUE_DO (L, "process_keys (keys)");
    else
      ok = leNIL;
  }
  STR_FREE (keystr);
}
END_DEFUN

/*
 * Find a macro given its name.
 */
int
get_macro (const char *name)
{
  int mp;
  int head_mp;
  lua_getglobal (L, "head_mp");
  head_mp = luaL_ref (L, LUA_REGISTRYINDEX);
  assert (name);
  for (mp = head_mp; mp != LUA_REFNIL; mp = get_macro_next (mp))
    if (!strcmp (get_macro_name (mp), name))
      return mp;
  return LUA_REFNIL;
}
