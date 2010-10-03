-- Generate loadlua.lua
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

h = io.open ("loadlua.lua", "w")
assert (h)

h:write ("-- Automatically generated file: DO NOT EDIT!\n" ..
         "-- Load Lua modules into " .. PACKAGE_NAME .. "\n" ..
         "\n")

for i in ipairs (arg) do
  h:write ("require \"" .. (string.gsub (arg[i], "%.lua$", "")) .. "\"\n")
end
