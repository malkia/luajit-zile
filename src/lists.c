/* Lisp lists

   Copyright (c) 2008 Free Software Foundation, Inc.

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

#include "main.h"
#include "extern.h"

#define LIST_GETTER(ty, field)                  \
  ty                                            \
  get_lists_ ## field (const le p)              \
  {                                             \
    return p->field;                            \
  }                                             \

#define LIST_SETTER(ty, field)                  \
  void                                          \
  set_lists_ ## field (le p, ty field)          \
  {                                             \
    p->field = field;                           \
  }

/*
 * Structure
 */
struct le
{
#define FIELD(ty, name) ty name;
#include "list_fields.h"
#undef FIELD
};

#define FIELD(ty, field)            \
  LIST_GETTER (ty, field)           \
  static LIST_SETTER (ty, field)

#include "list_fields.h"
#undef FIELD

le
leNew (const char *text)
{
  le new = (le) XZALLOC (struct le);

  if (text)
    set_lists_data (new, xstrdup (text));

  return new;
}

static le
leAddTail (le list, le element)
{
  le temp = list;

  /* if either element or list doesn't exist, return the `new' list */
  if (!element)
    return list;
  if (!list)
    return element;

  /* find the end element of the list */
  while (get_lists_next (temp))
    temp = get_lists_next (temp);

  /* tack ourselves on */
  set_lists_next (temp, element);

  /* return the list */
  return list;
}

le
leAddBranchElement (le list, le branch, int quoted)
{
  le temp = leNew (NULL);
  set_lists_branch (temp, branch);
  set_lists_quoted (temp, quoted);
  return leAddTail (list, temp);
}

le
leAddDataElement (le list, const char *data, int quoted)
{
  le newdata = leNew (data);
  set_lists_quoted (newdata, quoted);
  return leAddTail (list, newdata);
}
