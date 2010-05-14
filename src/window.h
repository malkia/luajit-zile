/* Window fields

   Copyright (c) 2009, 2010 Free Software Foundation, Inc.

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

FIELD(int, integer, next)		/* The next window in window list. */
TABLE_FIELD(bp)				/* The buffer displayed in window. */
FIELD(size_t, integer, topdelta)	/* The top line delta. */
FIELD(int, integer, lastpointn)		/* The last point line number. */
FIELD(size_t, integer, start_column)	/* The start column of the window (>0 if scrolled
                                           sideways). */
TABLE_FIELD(saved_pt)                   /* The point line pointer, line number and offset
                                           (used to hold the point in non-current windows). */
FIELD(size_t, integer, fwidth)		/* The formal width and height of the window. */
FIELD(size_t, integer, fheight)
FIELD(size_t, integer, ewidth)		/* The effective width and height of the window. */
FIELD(size_t, integer, eheight)
