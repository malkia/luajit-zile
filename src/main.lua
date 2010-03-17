-- Program invocation, startup and shutdown
--
-- Copyright (c) 2009, 2010 Free Software Foundation, Inc.
--
-- This file is part of GNU Zile.
--
-- GNU Zile is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- GNU Zile is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with GNU Zile; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.

usercmd = {} -- table of user commands

-- User command constructors
function defun (l, interactive)
  usercmd[l[1]] = {doc = l[2], interactive = interactive, func = l[3]}
end

function Defun (l)
  defun (l, true)
end

function Defun_noninteractive (l)
  defun (l, false)
end

-- Zile command to Lua bindings

leT = {data = "t"}
leNIL = {data = "nil"}

-- Turn a boolean into a Lisp boolean
function bool_to_lisp (b)
  return b and leT or leNIL
end
