/* Lisp variables

   Copyright (c) 2001, 2005, 2008 Free Software Foundation, Inc.

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

#ifndef LISTS_H
#define LISTS_H

typedef struct le * le;

#define FIELD(ty, field)                               \
  ty get_lists_ ## field (const le lp);
#include "list_fields.h"
#undef FIELD

le leNew (const char *text);

le leAddBranchElement (le list, le branch, int quoted);
le leAddDataElement (le list, const char *data, int quoted);

#endif
