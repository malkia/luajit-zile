/* Buffer fields

   Copyright (c) 2009 Free Software Foundation, Inc.

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

/* Cope with bad definition in some system headers. */
#undef lines

/* Dynamically allocated string fields of Buffer. */
FIELD_STR(name)           /* The name of the buffer. */
FIELD_STR(filename)       /* The file being edited. */

/* Other fields of Buffer. */
TABLE_FIELD(next)         /* Next buffer in buffer list. */
FIELD(const char *, string, eol) /* EOL string (up to 2 chars). */
TABLE_FIELD(lines)        /* The lines of text. */
FIELD(size_t, integer, last_line) /* The number of the last line in the buffer. */
FIELD(size_t, integer, goalc) /* Goal column for previous/next-line commands. */
TABLE_FIELD(pt) /* The point. */
TABLE_FIELD(mark)         /* The mark. */
TABLE_FIELD(markers)      /* Markers list (updated whenever text is changed). */
TABLE_FIELD(last_undop) /* Most recent undo delta. */
TABLE_FIELD(next_undop) /* Next undo delta to apply. */
TABLE_FIELD(vars)         /* Buffer-local variables. */
FIELD(bool, boolean, modified)     /* Modified flag. */
FIELD(bool, boolean, nosave)       /* The buffer need not be saved. */
FIELD(bool, boolean, needname)     /* On save, ask for a file name. */
FIELD(bool, boolean, temporary)    /* The buffer is a temporary buffer. */
FIELD(bool, boolean, readonly)     /* The buffer cannot be modified. */
FIELD(bool, boolean, overwrite)    /* The buffer is in overwrite mode. */
FIELD(bool, boolean, backup)       /* The old file has already been backed up. */
FIELD(bool, boolean, noundo)       /* Do not record undo informations. */
FIELD(bool, boolean, autofill)     /* The buffer is in Auto Fill mode. */
FIELD(bool, boolean, isearch)      /* The buffer is in Isearch loop. */
FIELD(bool, boolean, mark_active)  /* The mark is active. */
