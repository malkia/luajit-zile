/* Minibuffer handling

   Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2008, 2009 Free Software Foundation, Inc.

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

void
term_minibuf_write (const char *s)
{
  size_t x;

  CLUE_SET (L, y, integer, term_height () - 1);
  (void) CLUE_DO (L, "term_move (y, 0)");
  (void) CLUE_DO (L, "term_clrtoeol ()");

  for (x = 0; *s != '\0' && x < term_width (); s++)
    {
      CLUE_SET (L, c, integer, (int) (*(unsigned char *) s));
      (void) CLUE_DO (L, "term_addch (c)");
      ++x;
    }
}

static void
draw_minibuf_read (const char *prompt, const char *value,
                   size_t prompt_len, char *match, size_t pointo)
{
  int margin = 1, n = 0;

  term_minibuf_write (prompt);

  if (prompt_len + pointo + 1 >= term_width ())
    {
      margin++;
      (void) CLUE_DO (L, "term_addch (string.byte ('$'))");
      n = pointo - pointo % (term_width () - prompt_len - 2);
    }

  term_addnstr (value + n,
                MIN (term_width () - prompt_len - margin,
                     strlen (value) - n));
  term_addnstr (match, strlen (match));

  if (strlen (value + n) >= term_width () - prompt_len - margin)
    {
      CLUE_SET (L, y, integer, term_height () - 1);
      CLUE_SET (L, x, integer, term_width () - 1);
      (void) CLUE_DO (L, "term_move (y, x)");
      (void) CLUE_DO (L, "term_addch (string.byte ('$'))");
    }

  CLUE_SET (L, y, integer, term_height () - 1);
  CLUE_SET (L, x, integer, prompt_len + margin - 1 + pointo % (term_width () - prompt_len -
                                                               margin));
  (void) CLUE_DO (L, "term_move (y, x)");

  (void) CLUE_DO (L, "term_refresh ()");
}

static astr
do_minibuf_read (const char *prompt, const char *value, size_t pos,
                 int cp, int hp)
{
  static int overwrite_mode = 0;
  int c, thistab, lasttab = -1;
  size_t prompt_len;
  char *s;
  astr as = astr_new_cstr (value), saved = NULL;

  prompt_len = strlen (prompt);
  if (pos == SIZE_MAX)
    pos = astr_len (as);

  for (;;)
    {
      switch (lasttab)
        {
        case COMPLETION_MATCHEDNONUNIQUE:
          s = " [Complete, but not unique]";
          break;
        case COMPLETION_NOTMATCHED:
          s = " [No match]";
          break;
        case COMPLETION_MATCHED:
          s = " [Sole completion]";
          break;
        default:
          s = "";
        }
      draw_minibuf_read (prompt, astr_cstr (as), prompt_len, s, pos);

      thistab = -1;

      switch (c = getkey ())
        {
        case KBD_NOKEY:
          break;
        case KBD_CTRL | 'z':
          FUNCALL (suspend_emacs);
          break;
        case KBD_RET:
          CLUE_SET (L, y, integer, term_height () - 1);
          (void) CLUE_DO (L, "term_move (y, 0)");
          (void) CLUE_DO (L, "term_clrtoeol ()");
          if (saved)
            astr_delete (saved);
          return as;
        case KBD_CANCEL:
          CLUE_SET (L, y, integer, term_height () - 1);
          (void) CLUE_DO (L, "term_move (y, 0)");
          (void) CLUE_DO (L, "term_clrtoeol ()");
          if (saved)
            astr_delete (saved);
          astr_delete (as);
          return NULL;
        case KBD_CTRL | 'a':
        case KBD_HOME:
          pos = 0;
          break;
        case KBD_CTRL | 'e':
        case KBD_END:
          pos = astr_len (as);
          break;
        case KBD_CTRL | 'b':
        case KBD_LEFT:
          if (pos > 0)
            --pos;
          else
            ding ();
          break;
        case KBD_CTRL | 'f':
        case KBD_RIGHT:
          if (pos < astr_len (as))
            ++pos;
          else
            ding ();
          break;
        case KBD_CTRL | 'k':
          /* FIXME: do kill-register save. */
          if (pos < astr_len (as))
            astr_truncate (as, pos);
          else
            ding ();
          break;
        case KBD_BS:
          if (pos > 0)
            astr_remove (as, --pos, 1);
          else
            ding ();
          break;
        case KBD_CTRL | 'd':
        case KBD_DEL:
          if (pos < astr_len (as))
            astr_remove (as, pos, 1);
          else
            ding ();
          break;
        case KBD_INS:
          overwrite_mode = overwrite_mode ? 0 : 1;
          break;
        case KBD_META | 'v':
        case KBD_PGUP:
          if (LUA_NIL (cp))
            {
              ding ();
              break;
            }

          if (get_completion_poppedup (cp))
            {
              completion_scroll_down ();
              thistab = lasttab;
            }
          break;
        case KBD_CTRL | 'v':
        case KBD_PGDN:
          if (LUA_NIL (cp))
            {
              ding ();
              break;
            }

          if (get_completion_poppedup (cp))
            {
              completion_scroll_up ();
              thistab = lasttab;
            }
          break;
        case KBD_UP:
        case KBD_META | 'p':
          if (hp)
            {
              const char *elem;

              lua_rawgeti (L, LUA_REGISTRYINDEX, hp);
              lua_setglobal (L, "hp");
              (void) CLUE_DO (L, "elem = previous_history_element (hp)");
              CLUE_GET (L, elem, string, elem);

              if (elem)
                {
                  if (!saved)
                    saved = astr_cpy (astr_new (), as);

                  astr_cpy_cstr (as, elem);
                }
            }
          break;
        case KBD_DOWN:
        case KBD_META | 'n':
          if (hp)
            {
              const char *elem;

              lua_rawgeti (L, LUA_REGISTRYINDEX, hp);
              lua_setglobal (L, "hp");
              (void) CLUE_DO (L, "elem = next_history_element (hp)");
              CLUE_GET (L, elem, string, elem);

              if (elem)
                astr_cpy_cstr (as, elem);
              else if (saved)
                {
                  astr_cpy (as, saved);
                  astr_delete (saved);
                  saved = NULL;
                }
            }
          break;
        case KBD_TAB:
        got_tab:
          if (LUA_NIL (cp))
            {
              ding ();
              break;
            }

          if (lasttab != -1 && lasttab != COMPLETION_NOTMATCHED
              && get_completion_poppedup (cp))
            {
              completion_scroll_up ();
              thistab = lasttab;
            }
          else
            {
              lua_rawgeti (L, LUA_REGISTRYINDEX, cp);
              lua_setglobal (L, "cp");
              CLUE_SET (L, search, string, astr_cstr (as));
              (void) CLUE_DO (L, "ret = completion_try (cp, search)");
              CLUE_GET (L, ret, integer, thistab);

              switch (thistab)
                {
                case COMPLETION_NONUNIQUE:
                case COMPLETION_MATCHEDNONUNIQUE:
                  popup_completion (cp);
                case COMPLETION_MATCHED:
                  {
                    astr bs = astr_new ();
                    if (get_completion_filename (cp))
                      astr_cat_cstr (bs, get_completion_path (cp));
                    astr_ncat_cstr (bs, get_completion_match (cp), get_completion_matchsize (cp));
                    if (strncmp (astr_cstr (as), astr_cstr (bs),
                                 astr_len (bs)) != 0)
                      thistab = -1;
                    astr_delete (as);
                    as = bs;
                    pos = astr_len (as);
                    break;
                  }
                case COMPLETION_NOTMATCHED:
                  ding ();
                }
            }
          break;
        case ' ':
          if (!LUA_NIL (cp))
            goto got_tab;
          /* FALLTHROUGH */
        default:
          if (c > 255 || !isprint (c))
            {
              ding ();
              break;
            }
          astr_insert_char (as, pos++, c);
          if (overwrite_mode && pos != astr_len (as))
            astr_remove (as, pos, 1);
        }

      lasttab = thistab;
    }
}

char *
term_minibuf_read (const char *prompt, const char *value, size_t pos,
                   int cp, int hp)
{
  Window *wp, *old_wp = cur_wp;
  char *s = NULL;
  astr as;

  if (hp != LUA_NOREF)
    {
      lua_rawgeti (L, LUA_REGISTRYINDEX, hp);
      lua_setglobal (L, "hp");
      (void) CLUE_DO (L, "prepare_history (hp)");
    }

  as = do_minibuf_read (prompt, value, pos, cp, hp);
  if (as)
    {
      s = xstrdup (astr_cstr (as));
      astr_delete (as);
    }

  if (!LUA_NIL (cp) && get_completion_poppedup (cp)
      && (wp = find_window ("*Completions*")) != NULL)
    {
      set_current_window (wp);
      if (get_completion_close (cp))
        FUNCALL (delete_window);
      else if (get_completion_old_bp (cp))
        switch_to_buffer (get_completion_old_bp (cp));
      set_current_window (old_wp);
    }

  return s;
}
