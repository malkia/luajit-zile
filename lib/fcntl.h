/* DO NOT EDIT! GENERATED AUTOMATICALLY! */
/* Like <fcntl.h>, but with non-working flags defined to 0.

   Copyright (C) 2006-2008 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* written by Paul Eggert */

#pragma GCC system_header

#if defined __need_system_fcntl_h
/* Special invocation convention.  */

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include_next <fcntl.h>

#else
/* Normal invocation convention.  */

#ifndef _GL_FCNTL_H

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
/* The include_next requires a split double-inclusion guard.  */
#include_next <fcntl.h>

#ifndef _GL_FCNTL_H
#define _GL_FCNTL_H


/* Declare overridden functions.  */

#ifdef __cplusplus
extern "C" {
#endif

#if (1 && 0) || defined FCHDIR_REPLACEMENT
# undef open
# define open rpl_open
extern int open (const char *filename, int flags, ...);
#endif

#ifdef __cplusplus
}
#endif


/* Fix up the O_* macros.  */

#if !defined O_DIRECT && defined O_DIRECTIO
/* Tru64 spells it `O_DIRECTIO'.  */
# define O_DIRECT O_DIRECTIO
#endif

#ifndef O_DIRECT
# define O_DIRECT 0
#endif

#ifndef O_DIRECTORY
# define O_DIRECTORY 0
#endif

#ifndef O_DSYNC
# define O_DSYNC 0
#endif

#ifndef O_NDELAY
# define O_NDELAY 0
#endif

#ifndef O_NOATIME
# define O_NOATIME 0
#endif

#ifndef O_NONBLOCK
# define O_NONBLOCK O_NDELAY
#endif

#ifndef O_NOCTTY
# define O_NOCTTY 0
#endif

#ifndef O_NOFOLLOW
# define O_NOFOLLOW 0
#endif

#ifndef O_NOLINKS
# define O_NOLINKS 0
#endif

#ifndef O_RSYNC
# define O_RSYNC 0
#endif

#ifndef O_SYNC
# define O_SYNC 0
#endif

/* For systems that distinguish between text and binary I/O.
   O_BINARY is usually declared in fcntl.h  */
#if !defined O_BINARY && defined _O_BINARY
  /* For MSC-compatible compilers.  */
# define O_BINARY _O_BINARY
# define O_TEXT _O_TEXT
#endif

#ifdef __BEOS__
  /* BeOS 5 has O_BINARY and O_TEXT, but they have no effect.  */
# undef O_BINARY
# undef O_TEXT
#endif

#ifndef O_BINARY
# define O_BINARY 0
# define O_TEXT 0
#endif


#endif /* _GL_FCNTL_H */
#endif /* _GL_FCNTL_H */
#endif
