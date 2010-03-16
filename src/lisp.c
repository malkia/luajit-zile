/* Lisp parser

   Copyright (c) 2001, 2005, 2008, 2009 Free Software Foundation, Inc.

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

le leNIL, leT;

struct fentry
{
  const char *name;		/* The function name. */
  Function func;		/* The function pointer. */
  bool interactive;             /* Whether function can be used interactively. */
  const char *doc;		/* Documentation string. */
};
typedef struct fentry fentry;

static fentry fentry_table[] = {
#define X(zile_name, c_name, interactive, doc)   \
  {zile_name, F_ ## c_name, interactive, doc},
#include "tbl_funcs.h"
#undef X
};

#define fentry_table_size (sizeof (fentry_table) / sizeof (fentry_table[0]))

static fentry *
get_fentry (const char *name)
{
  size_t i;
  assert (name);
  for (i = 0; i < fentry_table_size; ++i)
    if (!strcmp (name, fentry_table[i].name))
      return &fentry_table[i];
  return NULL;
}

Function
get_function (const char *name)
{
  fentry * f = get_fentry (name);
  return f ? f->func : NULL;
}

/* Return function's interactive flag, or -1 if not found. */
int
get_function_interactive (const char *name)
{
  fentry * f = get_fentry (name);
  return f ? f->interactive : -1;
}

const char *
get_function_doc (const char *name)
{
  fentry * f = get_fentry (name);
  return f ? f->doc : NULL;
}

const char *
get_function_name (Function p)
{
  size_t i;
  for (i = 0; i < fentry_table_size; ++i)
    if (fentry_table[i].func == p)
      return fentry_table[i].name;
  return NULL;
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
    undo_save (UNDO_START_SEQUENCE, get_buffer_pt (cur_bp), 0, 0);
  for (uni = 0; ret && uni < uniarg; ++uni)
    ret = func ();
  if (undo)
    undo_save (UNDO_END_SEQUENCE, get_buffer_pt (cur_bp), 0, 0);

  return bool_to_lisp (ret);
}

le
execute_function (const char *name, int uniarg)
{
  Function func = get_function (name);
  Macro *mp;

  if (func)
    return func (uniarg, true, LUA_NOREF);
  else
    {
      mp = get_macro (name);
      if (mp)
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

  if (lastflag & FLAG_SET_UNIARG)
    {
      if (lastflag & FLAG_UNIARG_EMPTY)
        astr_afmt (msg, "C-u ");
      else
        astr_afmt (msg, "%d ", uniarg);
    }
  astr_cat_cstr (msg, "M-x ");

  name = minibuf_read_function_name (astr_cstr (msg));
  astr_delete (msg);
  if (name == NULL)
    return false;

  ok = execute_function (name, uniarg);
  free ((char *) name);
}
END_DEFUN

/*
 * Read a function name from the minibuffer.
 */
static int functions_history = LUA_NOREF;
const char *
minibuf_read_function_name (const char *fmt, ...)
{
  va_list ap;
  char *ms;
  int cp;
  size_t i;

  (void) CLUE_DO (L, "cp = completion_new ()");
  lua_getglobal (L, "cp");
  cp = luaL_ref (L, LUA_REGISTRYINDEX);

  for (i = 0; i < fentry_table_size; ++i)
    if (fentry_table[i].interactive)
      {
        CLUE_SET (L, s, string, fentry_table[i].name);
        (void) CLUE_DO (L, "table.insert (cp.completions, s)");
      }
  add_macros_to_list (cp);

  va_start (ap, fmt);
  ms = minibuf_vread_completion (fmt, "", cp, functions_history,
                                 "No function name given",
                                 minibuf_test_in_completions,
                                 "Undefined function name `%s'", ap);
  va_end (ap);

  return ms;
}

static size_t
countNodes (le branch)
{
  int count;

  for (count = 0;
       !LUA_NIL (branch);
       branch = get_lists_next (branch), count++)
    ;
  return count;
}

static int
call_zile_command (lua_State *L)
{
  le trybranch;
  const char *keyword;
  fentry * func;
  assert (lua_isstring (L, -2));
  assert (lua_istable (L, -1));
  keyword = lua_tostring (L, -2);
  trybranch = luaL_ref (L, LUA_REGISTRYINDEX);
  func = get_fentry (keyword);
  if (func)
    lua_pushvalue (L, (func->func) (1, false, trybranch));
  else
    lua_pushnil (L);
  luaL_unref (L, LUA_REGISTRYINDEX, trybranch);
  return 1;
}

static le
leNew (const char *text)
{
  le new;
  lua_newtable (L);
  new = luaL_ref (L, LUA_REGISTRYINDEX);

  if (text)
    {
      lua_rawgeti (L, LUA_REGISTRYINDEX, new);
      lua_pushstring (L, xstrdup (text));
      lua_setfield (L, -2, "data");
      lua_pop (L, 1);
    }

  return new;
}

void
init_lisp (void)
{
  leNIL = leNew ("nil");
  leT = leNew ("t");
}

void
lisp_loadstring (astr as)
{
  CLUE_SET (L, s, string, astr_cstr (as));
  (void) CLUE_DO (L, "leEval (lisp_read (s))");
}

bool
lisp_loadfile (const char *file)
{
  FILE *fp = fopen (file, "r");

  if (fp != NULL)
    {
      astr bs = astr_fread (fp);
      lisp_loadstring (bs);
      astr_delete (bs);
      fclose (fp);
      return true;
    }

    return false;
}

DEFUN ("load", load)
/*+
Execute a file of Lisp code named FILE.
+*/
{
  if (!LUA_NIL (arglist) && countNodes (arglist) >= 2)
    ok = bool_to_lisp (lisp_loadfile (get_lists_data (get_lists_next (arglist))));
  else
    ok = leNIL;
}
END_DEFUN

void
init_eval (void)
{
  (void) CLUE_DO (L, "hp = history_new ()");
  lua_getglobal (L, "hp");
  functions_history = luaL_ref (L, LUA_REGISTRYINDEX);
  lua_register (L, "call_zile_command", call_zile_command);
}
