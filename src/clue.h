/* Clue: minimal C-Lua integration

   release 4

   Copyright (c) 2007, 2009 Reuben Thomas.

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation
   files (the "Software"), to deal in the Software without
   restriction, including without limitation the rights to use, copy,
   modify, merge, publish, distribute, sublicense, and/or sell copies
   of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:
   
   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.
   
   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. */


#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>


/* Error checking: Clue catches errors other than out of memory.
   Out of memory errors are thrown as normal. */


/* Before using Clue:

      * #include "clue.h"
      * at the top level of your Clue usage: CLUE_DECLS(L);
      * L is the handle for the rest of your Clue calls
*/
#define CLUE_DECLS(L)                           \
  extern lua_State *L

/* Call this macro at the top level of your usage, after
   CLUE_DECLS(). */
#define CLUE_DEFS(L)                            \
  lua_State *L

/* Call this macro before using the others, and check L is
   non-NULL on return. */
#define CLUE_INIT(L)                            \
  do {                                          \
    if ((L = luaL_newstate()))                  \
      luaL_openlibs(L);                         \
  } while (0)

/* Call this macro after last use of Clue. */
#define CLUE_CLOSE(L)                           \
  lua_close(L)

/* Set a Lua variable `lvar' of type 'lty' to C value `cexp'. */
#define CLUE_SET(L, lvar, lty, cexp)            \
  do {                                          \
    lua_checkstack(L, 2);                       \
    lua_pushstring(L, #lvar);                   \
    lua_push ## lty(L, cexp);                   \
    lua_rawset(L, LUA_GLOBALSINDEX);            \
  } while (0)

/* Read a value of type `lty' from Lua global `lvar' into C variable
   `cvar'. Strings should be copied if their value is required after
   further Clue calls. */
#define CLUE_GET(L, lvar, lty, cvar)            \
  do {                                          \
    lua_checkstack(L, 1);                       \
    lua_pushstring(L, #lvar);                   \
    lua_rawget(L, LUA_GLOBALSINDEX);            \
    cvar = lua_to ## lty(L, -1);                \
    lua_pop(L, 1);                              \
  } while (0)

/* Run some Lua code `code'. */
#define CLUE_DO(L, code)                        \
  (luaL_loadstring(L, code) || lua_pcall(L, 0, 0, 0))
