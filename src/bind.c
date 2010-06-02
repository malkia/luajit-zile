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

#include <assert.h>
#include <ctype.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "gl_array_list.h"
#include "gl_linked_list.h"

#include "main.h"
#include "extern.h"

/*--------------------------------------------------------------------------
 * Key binding.
 *--------------------------------------------------------------------------*/

#define FIELD(cty, lty, field)                     \
  static LUA_GETTER (binding, cty, lty, field)     \
  static LUA_SETTER (binding, cty, lty, field)
#define TABLE_FIELD(field)                            \
  static LUA_TABLE_GETTER (binding, field)            \
  static LUA_TABLE_SETTER (binding, field)

#include "binding.h"
#undef FIELD
#undef TABLE_FIELD

static int root_bindings;

static int
node_new (void)
{
  int p;

  lua_newtable (L);
  p = luaL_ref (L, LUA_REGISTRYINDEX);
  lua_newtable (L);
  set_binding_vec (p, luaL_ref (L, LUA_REGISTRYINDEX));

  return p;
}

static int
search_node (int tree, size_t key)
{
  CLUE_SET (L, key, integer, key);
  lua_rawgeti (L, LUA_REGISTRYINDEX, tree);
  lua_setglobal (L, "tree");
  CLUE_DO (L, "b = nil; for i = 1, #tree.vec do if tree.vec[i].key == key then b = tree.vec[i] end end");
  lua_getglobal (L, "b");
  return luaL_ref (L, LUA_REGISTRYINDEX);
}

static void
add_node (int tree, int p)
{
  /* Erase any previous binding the current key might have had in case
     it was non-prefix and is now being made prefix, as we don't want
     to accidentally create a default for the prefix map. */
  lua_rawgeti (L, LUA_REGISTRYINDEX, tree);
  lua_setglobal (L, "tree");
  lua_rawgeti (L, LUA_REGISTRYINDEX, p);
  lua_setglobal (L, "p");
  CLUE_DO (L, "tree.func = nil; table.insert (tree.vec, p)");
}

static void
bind_key_vec (int tree, gl_list_t keys, size_t from, const char * func)
{
  int p, s = search_node (tree, (size_t) gl_list_get_at (keys, from));
  size_t n = gl_list_size (keys) - from;

  if (s == LUA_REFNIL)
    {
      p = node_new ();
      set_binding_key (p, (size_t) gl_list_get_at (keys, from));
      add_node (tree, p);
      if (n == 1)
        set_binding_func (p, func);
      else if (n > 0)
        bind_key_vec (p, keys, from + 1, func);
    }
  else if (n > 1)
    bind_key_vec (s, keys, from + 1, func);
  else
    set_binding_func (s, func);
}

static int
search_key (int tree, gl_list_t keys, size_t from)
{
  int p = search_node (tree, (size_t) gl_list_get_at (keys, from));

  if (p != LUA_REFNIL)
    {
      if (gl_list_size (keys) - from == 1)
        return p;
      else
        return search_key (p, keys, from + 1);
    }

  return LUA_REFNIL;
}

static astr
make_completion (gl_list_t keys)
{
  astr as = astr_new (), key;
  size_t i, len = 0;

  for (i = 0; i < gl_list_size (keys); i++)
    {
      if (i > 0)
        {
          astr_cat_char (as, ' ');
          len++;
        }
      key = chordtostr ((size_t) gl_list_get_at (keys, i));
      astr_cat (as, key);
      astr_delete (key);
    }

  return astr_cat_char (as, '-');
}

size_t
do_binding_completion (astr as)
{
  size_t key;
  astr bs = astr_new ();

  if (lastflag () & FLAG_SET_UNIARG)
    {
      int arg = last_uniarg;

      if (arg < 0)
        {
          astr_cat_cstr (bs, "- ");
          arg = -arg;
        }

      do {
        astr_insert_char (bs, 0, ' ');
        astr_insert_char (bs, 0, arg % 10 + '0');
        arg /= 10;
      } while (arg != 0);
    }

  minibuf_write ("%s%s%s",
                 lastflag () & (FLAG_SET_UNIARG | FLAG_UNIARG_EMPTY) ? "C-u " : "",
                 astr_cstr (bs),
                 astr_cstr (as));
  astr_delete (bs);
  key = getkey ();
  minibuf_clear ();

  return key;
}

/* Get a key sequence from the keyboard; the sequence returned
   has at most the last stroke unbound. */
gl_list_t
get_key_sequence (void)
{
  gl_list_t keys = gl_list_create_empty (GL_ARRAY_LIST,
                                         NULL, NULL, NULL, true);
  size_t key;

  do
    key = getkey ();
  while (key == KBD_NOKEY);
  gl_list_add_last (keys, (void *) key);
  for (;;)
    {
      astr as;
      int p = search_key (root_bindings, keys, 0);
      if (p == LUA_REFNIL || get_binding_func (p) != NULL)
        break;
      as = make_completion (keys);
      gl_list_add_last (keys, (void *) do_binding_completion (as));
      astr_delete (as);
    }

  return keys;
}

const char *
get_function_by_keys (gl_list_t keys)
{
  int p;

  /* Detect Meta-digit */
  if (gl_list_size (keys) == 1)
    {
      size_t key = (size_t) gl_list_get_at (keys, 0);
      if (key & KBD_META &&
          (isdigit ((int) (key & 0xff)) || (int) (key & 0xff) == '-'))
        return "universal-argument";
    }

  /* See if we've got a valid key sequence */
  p = search_key (root_bindings, keys, 0);

  return p != LUA_REFNIL ? get_binding_func (p) : NULL;
}

static bool
self_insert_command (void)
{
  int ret = true;
  /* Mask out ~KBD_CTRL to allow control sequences to be themselves. */
  int key = (int) (lastkey () & ~KBD_CTRL);
  deactivate_mark ();
  if (key <= 0xff)
    {
      if (isspace (key) && get_buffer_autofill (cur_bp ()) &&
          get_goalc () > (size_t) get_variable_number ("fill-column"))
        fill_break_line ();
      insert_char (key);
    }
  else
    {
      ding ();
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

static const char * _last_command = "";
static const char * _this_command = "";

const char *
last_command (void)
{
  return _last_command;
}

void
set_this_command (const char * cmd)
{
  _this_command = cmd;
}

void
process_command (void)
{
  gl_list_t keys = get_key_sequence ();
  const char * name = get_function_by_keys (keys);

  set_thisflag (lastflag () & FLAG_DEFINING_MACRO);
  minibuf_clear ();

  if (function_exists (name))
    {
      set_this_command (name);
      execute_function (name, last_uniarg, (lastflag () & FLAG_SET_UNIARG) != 0, LUA_NOREF);
      _last_command = _this_command;
    }
  else
    {
      astr as = keyvectostr (keys);
      minibuf_error ("%s is undefined", astr_cstr (as));
      astr_delete (as);
    }
  gl_list_free (keys);

  /* Only add keystrokes if we were already in macro defining mode
     before the function call, to cope with start-kbd-macro. */
  if (lastflag () & FLAG_DEFINING_MACRO && thisflag () & FLAG_DEFINING_MACRO)
    add_cmd_to_macro ();

  if (!(thisflag () & FLAG_SET_UNIARG))
    last_uniarg = 1;

  if (strcmp (last_command (), "undo") != 0)
    set_buffer_next_undop (cur_bp (), get_buffer_last_undop (cur_bp ()));

  set_lastflag (thisflag ());
}

void
init_default_bindings (void)
{
  size_t i;
  gl_list_t keys = gl_list_create_empty (GL_ARRAY_LIST,
                                         NULL, NULL, NULL, true);

  root_bindings = node_new ();
  lua_rawgeti (L, LUA_REGISTRYINDEX, root_bindings);
  lua_setglobal (L, "root_bindings");

  /* Bind all printing keys to self_insert_command */
  gl_list_add_last (keys, NULL);
  for (i = 0; i <= 0xff; i++)
    {
      if (isprint (i))
        {
          gl_list_set_at (keys, 0, (void *) i);
          bind_key_vec (root_bindings, keys, 0, "self-insert-command");
        }
    }
  gl_list_free (keys);

  /* FIXME: Load from path */
  CLUE_DO (L, "lisp_loadfile (\"default-bindings.el\")");
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
  gl_list_t keys;

  STR_INIT (keystr);
  if (keystr != NULL)
    {
      keys = keystrtovec (keystr);
      if (keys == NULL)
        {
          minibuf_error ("Key sequence %s is invalid", keystr);
          return leNIL;
        }
    }
  else
    {
      astr as;

      minibuf_write ("Set key globally: ");
      keys = get_key_sequence ();
      as = keyvectostr (keys);
      keystr = xstrdup (astr_cstr (as));
      astr_delete (as);
    }

  STR_INIT (name)
  else
    name = minibuf_read_function_name ("Set key %s to command: ",
                                       keystr);
  if (name == NULL)
    return leNIL;

  if (!function_exists (name)) /* Possible if called non-interactively */
    {
      minibuf_error ("No such function `%s'", name);
      return leNIL;
    }
  bind_key_vec (root_bindings, keys, 0, name);

  gl_list_free (keys);
  STR_FREE (keystr);
  STR_FREE (name);
}
END_DEFUN

static void
walk_bindings_tree (int tree, gl_list_t keys,
                    void (*process) (astr key, int p, void *st), void *st)
{
  size_t i, j, vecnum;
  const char *s;

  lua_rawgeti (L, LUA_REGISTRYINDEX, tree);
  lua_setglobal (L, "tree");
  CLUE_DO (L, "s = nil; if tree.key then s = chordtostr (tree.key) end");
  CLUE_GET (L, s, string, s);
  if (s != NULL)
    gl_list_add_last (keys, astr_new_cstr (s));

  lua_rawgeti (L, LUA_REGISTRYINDEX, tree);
  CLUE_DO (L, "vecnum = #tree.vec");
  CLUE_GET (L, vecnum, integer, vecnum);
  for (i = 1; i <= vecnum; ++i)
    {
      int p;
      CLUE_SET (L, i, integer, i);
      lua_rawgeti (L, LUA_REGISTRYINDEX, tree);
      lua_setglobal (L, "tree");
      CLUE_DO (L, "p = tree.vec[i]");
      lua_getglobal (L, "p");
      p = luaL_ref (L, LUA_REGISTRYINDEX);
      if (get_binding_func (p) != NULL)
        {
          astr key = astr_new ();
          astr as = chordtostr (get_binding_key (p));
          for (j = 1; j < gl_list_size (keys); j++)
            {
              astr_cat (key, (astr) gl_list_get_at (keys, j));
              astr_cat_char (key, ' ');
            }
          astr_cat (key, as);
          astr_delete (as);
          process (key, p, st);
          astr_delete (key);
        }
      else
        walk_bindings_tree (p, keys, process, st);
    }

  if (gl_list_size (keys) > 0)
    {
      astr_delete ((astr) gl_list_get_at (keys, gl_list_size (keys) - 1));
      assert (gl_list_remove_at (keys, gl_list_size (keys) - 1));
    }
}

static void
walk_bindings (int tree, void (*process) (astr key, int p, void *st),
               void *st)
{
  gl_list_t l = gl_list_create_empty (GL_LINKED_LIST,
                                      NULL, NULL, NULL, true);
  walk_bindings_tree (tree, l, process, st);
  gl_list_free (l);
}

DEFUN ("where-is", where_is)
/*+
Print message listing key sequences that invoke the command DEFINITION.
Argument is a command name.  If the prefix arg is non-nil, insert the
message in the buffer.
+*/
{
  const char *name = minibuf_read_function_name ("Where is command: "), *bindings;

  ok = leNIL;

  if (name && function_exists (name))
    {
      CLUE_SET (L, name, string, name);
      CLUE_DO (L, "g = {f = name, bindings = \"\"}");
      CLUE_DO (L, "walk_bindings (root_bindings, gather_bindings, g)");
      CLUE_DO (L, "bindings = g.bindings");
      CLUE_GET (L, bindings, string, bindings);

      if (strlen (bindings) == 0)
        minibuf_write ("%s is not on any key", name);
      else
        {
          astr as = astr_new ();
          astr_afmt (as, "%s is on %s", name, bindings);
          if (lastflag () & FLAG_SET_UNIARG)
            bprintf ("%s", astr_cstr (as));
          else
            minibuf_write ("%s", astr_cstr (as));
          astr_delete (as);
        }
      ok = leT;
    }

  free ((char *) name);
}
END_DEFUN

static void
print_binding (astr key, int p, void *st GCC_UNUSED)
{
  bprintf ("%-15s %s\n", astr_cstr (key), get_binding_func (p));
}

static void
write_bindings_list (va_list ap GCC_UNUSED)
{
  bprintf ("Key translations:\n");
  bprintf ("%-15s %s\n", "key", "binding");
  bprintf ("%-15s %s\n", "---", "-------");

  walk_bindings (root_bindings, print_binding, NULL);
}

DEFUN ("describe-bindings", describe_bindings)
/*+
Show a list of all defined keys, and their definitions.
+*/
{
  write_temp_buffer ("*Help*", true, write_bindings_list);
}
END_DEFUN
