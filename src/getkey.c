/* Getting and ungetting key strokes

   Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2008, 2009 Free Software Foundation, Inc.

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

#include <stdio.h>
#include <stdlib.h>

#include "main.h"
#include "extern.h"

size_t
xgetkey (int mode, size_t timeout)
{
  size_t key;

  CLUE_SET (L, mode, integer, mode);
  CLUE_SET (L, timeout, integer, timeout);
  CLUE_DO (L, "key = xgetkey (mode, timeout)");
  CLUE_GET (L, key, integer, key);

  return key;
}

size_t
getkey (void)
{
  return xgetkey (0, 0);
}
