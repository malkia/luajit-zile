/* Main types and definitions

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

#ifndef ZILE_H
#define ZILE_H

#include <stdlib.h>
#include <stdbool.h>
#include <limits.h>
#include <lua.h>
#include <lauxlib.h>
#include "lua-posix.h"
#include "lua-bitop.h"
#include "config.h"
#include "xalloc.h"
#include "size_max.h"
#include "minmax.h"
#include "gl_xlist.h"

#include "clue.h"
#include "astr.h"
#include "lists.h"

#define ZILE_VERSION_STRING	"GNU " PACKAGE_NAME " " VERSION

/*--------------------------------------------------------------------------
 * Main editor structures.
 *--------------------------------------------------------------------------*/

/* Opaque types. */
typedef struct Region Region;
typedef struct Undo Undo;
typedef struct Macro Macro;
typedef struct Binding *Binding;

/* Undo delta types. */
enum
{
  UNDO_REPLACE_BLOCK,		/* Replace a block of characters. */
  UNDO_START_SEQUENCE,		/* Start a multi operation sequence. */
  UNDO_END_SEQUENCE		/* End a multi operation sequence. */
};

enum
{
  COMPLETION_NOTMATCHED,
  COMPLETION_MATCHED,
  COMPLETION_MATCHEDNONUNIQUE,
  COMPLETION_NONUNIQUE
};

/*--------------------------------------------------------------------------
 * Object field getter and setter generators.
 *--------------------------------------------------------------------------*/

#define GETTER(Obj, name, ty, field)            \
  ty                                            \
  get_ ## name ## _ ## field (const Obj *_p)    \
  {                                             \
    return _p->field;                           \
  }                                             \

#define SETTER(Obj, name, ty, field)                    \
  void                                                  \
  set_ ## name ## _ ## field (Obj *_p, ty field)        \
  {                                                     \
    _p->field = field;                                  \
  }

#define STR_SETTER(Obj, name, field)                            \
  void                                                          \
  set_ ## name ## _ ## field (Obj *p, const char *field)        \
  {                                                             \
    free ((char *) p->field);                                   \
    p->field = field ? xstrdup (field) : NULL;                  \
  }

#define LUA_GETTER(name, cty, lty, field)       \
  cty                                           \
  get_ ## name ## _ ## field (const le p)       \
  {                                             \
    cty ret;                                    \
    lua_rawgeti (L, LUA_REGISTRYINDEX, p);      \
    lua_getfield (L, -1, #field);               \
    ret = lua_to ## lty (L, -1);                \
    lua_pop (L, 2);                             \
    return ret;                                 \
  }

#define LUA_TABLE_GETTER(name, field)           \
  int                                           \
  get_ ## name ## _ ## field (const le p)       \
  {                                             \
    int ret = LUA_REFNIL;                       \
    lua_rawgeti (L, LUA_REGISTRYINDEX, p);      \
    lua_getfield (L, -1, #field);               \
    if (lua_istable (L, -1))                    \
      ret = luaL_ref (L, LUA_REGISTRYINDEX);    \
    lua_pop (L, 1);                             \
    return ret;                                 \
  }

#define LUA_SETTER(name, cty, lty, field)               \
  void                                                  \
  set_ ## name ## _ ## field (const le p, cty val)      \
  {                                                     \
    lua_rawgeti (L, LUA_REGISTRYINDEX, p);              \
    lua_push ## lty (L, val);                           \
    lua_setfield (L, -2, #field);                       \
    lua_pop (L, 1);                                     \
  }

#define LUA_TABLE_SETTER(name, field)                   \
  void                                                  \
  set_ ## name ## _ ## field (const le p, int val)      \
  {                                                     \
    lua_rawgeti (L, LUA_REGISTRYINDEX, p);              \
    lua_rawgeti (L, LUA_REGISTRYINDEX, val);            \
    lua_setfield (L, -2, #field);                       \
    lua_pop (L, 1);                                     \
  }

/* Alias to make macros above work */
#define lua_tolightuserdata lua_touserdata

/*--------------------------------------------------------------------------
 * Zile commands to C bindings.
 *--------------------------------------------------------------------------*/

#define LUA_NIL(e) \
  ((e) == LUA_NOREF || (e) == LUA_REFNIL)       \

/* Turn a bool into a Lisp boolean */
#define bool_to_lisp(b) ((b) ? leT : leNIL)

/* Define an interactive function. */
#define DEFUN(zile_func, c_func) \
  le F_ ## c_func (long uniarg GCC_UNUSED, bool is_uniarg GCC_UNUSED, le arglist GCC_UNUSED) \
  {                                                                     \
    le ok = leT;
#define DEFUN_ARGS(zile_func, c_func, args) \
  DEFUN(zile_func, c_func)                  \
  args
#define END_DEFUN    \
    return ok;       \
  }

/* Define a non-user-visible function. */
#define DEFUN_NONINTERACTIVE(zile_func, c_func) \
  DEFUN(zile_func, c_func)
#define DEFUN_NONINTERACTIVE_ARGS(zile_func, c_func, args) \
  DEFUN_ARGS(zile_func, c_func, args)

/* String argument. */
#define STR_ARG(name) \
  const char *name = NULL; \
  bool free_ ## name = true;
#define STR_INIT(name)                          \
  if (!LUA_NIL (arglist) && !LUA_NIL (get_lists_next (arglist))) \
    { \
      name = get_lists_data (get_lists_next (arglist));   \
      arglist = get_lists_next (arglist);           \
      free_ ## name = false; \
    }
#define STR_FREE(name) \
  if (free_ ## name) \
    free ((char *) name);

/* Integer argument. */
#define INT_ARG(name) \
  long name = 1;
#define INT_INIT(name) \
  if (!LUA_NIL (arglist) && !LUA_NIL (get_lists_next (arglist))) \
    { \
      const char *s = get_lists_data (get_lists_next (arglist));  \
      arglist = get_lists_next (arglist);                   \
      name = strtol (s, NULL, 10); \
      if (name == LONG_MAX) \
        ok = leNIL; \
    }

/* Integer argument which can either be argument or uniarg. */
#define INT_OR_UNIARG(name) \
  long name = 1;            \
  bool noarg = false;
#define INT_OR_UNIARG_INIT(name)                                        \
  INT_INIT (name)                                                       \
  else                                                                  \
    {                                                                   \
      if (!(lastflag & FLAG_SET_UNIARG) && !is_uniarg &&                \
          arglist != LUA_NOREF)                                         \
        noarg = true;                                                   \
      name = uniarg;                                                    \
    }

/* Boolean argument. */
#define BOOL_ARG(name) \
  bool name = true;
#define BOOL_INIT(name) \
  if (!LUA_NIL (arglist) && !LUA_NIL (get_lists_next (arglist))) \
    { \
      const char *s = get_lists_data (get_lists_next (arglist)); \
      arglist = get_lists_next (arglist);                  \
      if (strcmp (s, "nil") == 0) \
        name = false; \
    }

/* Call an interactive function. */
#define FUNCALL(c_func)                         \
  F_ ## c_func (1, false, LUA_NOREF)

/* Call an interactive function with a universal argument. */
#define FUNCALL_ARG(c_func, uniarg)             \
  F_ ## c_func (uniarg, true, LUA_NOREF)

/*--------------------------------------------------------------------------
 * Keyboard handling.
 *--------------------------------------------------------------------------*/

#define GETKEY_DELAYED                  0001
#define GETKEY_UNFILTERED               0002

/* Special value returned for invalid key codes, or when no key is pressed. */
#define KBD_NOKEY                       UINT_MAX

/* Key modifiers. */
#define KBD_CTRL                        01000
#define KBD_META                        02000

/* Common non-alphanumeric keys. */
#define KBD_CANCEL                      (KBD_CTRL | 'g')
#define KBD_TAB                         00402
#define KBD_RET                         00403
#define KBD_PGUP                        00404
#define KBD_PGDN                        00405
#define KBD_HOME                        00406
#define KBD_END                         00407
#define KBD_DEL                         00410
#define KBD_BS                          00411
#define KBD_INS                         00412
#define KBD_LEFT                        00413
#define KBD_RIGHT                       00414
#define KBD_UP                          00415
#define KBD_DOWN                        00416
#define KBD_F1                          00420
#define KBD_F2                          00421
#define KBD_F3                          00422
#define KBD_F4                          00423
#define KBD_F5                          00424
#define KBD_F6                          00425
#define KBD_F7                          00426
#define KBD_F8                          00427
#define KBD_F9                          00430
#define KBD_F10                         00431
#define KBD_F11                         00432
#define KBD_F12                         00433

/*--------------------------------------------------------------------------
 * Miscellaneous stuff.
 *--------------------------------------------------------------------------*/

/* Global flags, stored in thisflag and lastflag. */
#define FLAG_NEED_RESYNC	0001	/* A resync is required. */
#define FLAG_QUIT		0002	/* The user has asked to quit. */
#define FLAG_SET_UNIARG		0004	/* The last command modified the
                                           universal arg variable `uniarg'. */
#define FLAG_UNIARG_EMPTY	0010	/* Current universal arg is just C-u's
                                           with no number. */
#define FLAG_DEFINING_MACRO	0020	/* We are defining a macro. */

/*
 * Zile font codes
 */
#define FONT_NORMAL		0000
#define FONT_REVERSE		0001

/* Default waitkey pause in ds */
#define WAITKEY_DEFAULT 20

/* Avoid warnings about unused parameters. */
#undef GCC_UNUSED
#ifdef __GNUC__
#define GCC_UNUSED __attribute__ ((unused))
#else
#define GCC_UNUSED
#endif

#endif /* !ZILE_H */
