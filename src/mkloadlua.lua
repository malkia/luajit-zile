-- Generate loadlua.h
--
-- Copyright (c) 2010 Free Software Foundation, Inc.
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

prog = {
  name = "mkloadlua"
}

-- FIXME: Generate a Lua file, not a C file
require "lib"

h = io.open ("loadlua.h", "w")
assert (h)

h:write ("/*\n" ..
         " * Automatically generated file: DO NOT EDIT!\n" ..
         " * Load Lua modules into " .. PACKAGE_NAME .. "\n" ..
         " */\n" ..
         "\n")

for i in ipairs (arg) do
  if arg[i] then
    local f = string.gsub (arg[i], "%.lua$", "")
    h:write ("X (\"" .. f .. "\")\n")
  end
end

h:close ()
