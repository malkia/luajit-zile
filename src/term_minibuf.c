/* Minibuffer handling

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

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "main.h"
#include "extern.h"

char *
term_minibuf_read (const char *prompt, const char *value, long pos,
                   int cp, int hp)
{
  int wp, old_wp = cur_wp ();
  char *s = NULL;
  astr as;

  if (hp != LUA_REFNIL)
    {
      lua_rawgeti (L, LUA_REGISTRYINDEX, hp);
      lua_setglobal (L, "hp");
      CLUE_DO (L, "history_prepare (hp)");
    }

  {
    const char *s;
    CLUE_SET (L, prompt, string, prompt);
    CLUE_SET (L, value, string, value);
    CLUE_SET (L, pos, integer, pos);
    lua_rawgeti (L, LUA_REGISTRYINDEX, cp);
    lua_setglobal (L, "cp");
    lua_rawgeti (L, LUA_REGISTRYINDEX, hp);
    lua_setglobal (L, "hp");
    CLUE_DO (L, "s = do_minibuf_read (prompt, value, pos, cp, hp)");
    CLUE_GET (L, s, string, s);
    as = s ? astr_new_cstr (s) : NULL;
  }
  if (as)
    {
      s = xstrdup (astr_cstr (as));
      astr_delete (as);
    }

  CLUE_SET (L, name, string, "*Completions*");
  CLUE_DO (L, "wp = find_window (name)");
  lua_getglobal (L, "wp");
  wp = luaL_ref (L, LUA_REGISTRYINDEX);
  if (cp != LUA_REFNIL && get_completion_poppedup (cp) && wp != LUA_REFNIL)
    {
      lua_rawgeti (L, LUA_REGISTRYINDEX, wp);
      lua_setglobal (L, "wp");
      CLUE_DO (L, "set_current_window (wp)");
      if (get_completion_close (cp))
        FUNCALL (delete_window);
      else if (get_completion_old_bp (cp))
        {
          lua_rawgeti (L, LUA_REGISTRYINDEX, get_completion_old_bp (cp));
          lua_setglobal (L, "bp");
          CLUE_DO (L, "switch_to_buffer (bp)");
        }
      lua_rawgeti (L, LUA_REGISTRYINDEX, old_wp);
      lua_setglobal (L, "old_wp");
      CLUE_DO (L, "set_current_window (old_wp)");
    }

  return s;
}
