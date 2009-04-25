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

#include <stdlib.h>
#include <string.h>

#include "main.h"
#include "extern.h"
#include "clue.h"

void
init_lisp (void)
{
  leNIL = leNew ("nil");
  leT = leNew ("t");
}


enum tokenname
{
  T_EOF,
  T_CLOSEPAREN,
  T_OPENPAREN,
  T_NEWLINE,
  T_QUOTE,
  T_WORD
};

static le
lisp_read (le list, astr as, size_t * pos)
{
  astr tok;
  enum tokenname tokenid;
  int quoted = 0;

  for (;;)
    {
      const char *tok_lua;

      CLUE_SET (L, as, string, astr_cstr (as));
      CLUE_SET (L, pos, integer, *pos + 1);
      CLUE_DO (L, "tok, tokenid, pos = read_token (as, pos)");
      CLUE_GET (L, tok, string, tok_lua);
      tok = astr_new_cstr (tok_lua);
      CLUE_GET (L, tokenid, integer, tokenid);
      CLUE_GET (L, pos, integer, *pos);
      (*pos)--;

      switch (tokenid)
        {
        case T_QUOTE:
          quoted = 1;
          break;

        case T_OPENPAREN:
          list = leAddBranchElement (list, lisp_read (NULL, as, pos), quoted);
          quoted = 0;
          break;

        case T_NEWLINE:
          quoted = 0;
          break;

        case T_WORD:
          list = leAddDataElement (list, astr_cstr (tok), quoted);
          quoted = 0;
          break;

        case T_CLOSEPAREN:
        case T_EOF:
          quoted = 0;
          astr_delete (tok);
          return list;
        }

      astr_delete (tok);
    }
}

void
lisp_loadstring (astr as)
{
  size_t pos = 0;
  le list = lisp_read (NULL, as, &pos);

  leEval (list);
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
  if (arglist && countNodes (arglist) >= 2)
    ok = bool_to_lisp (lisp_loadfile (get_lists_data (get_lists_next (arglist))));
  else
    ok = leNIL;
}
END_DEFUN
