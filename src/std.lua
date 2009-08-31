-- Subset of Lua stdlib
--
-- Copyright (c) 2000-2009 stdlib authors.
--
-- This file is NOT part of GNU Zile. See the stdlib project at
-- http://luaforge.net/projects/stdlib/ for more information.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.


-- @func __index: Give strings a subscription operator
--   @param s: string
--   @param n: index
-- @returns
--   @param s_: string.sub (s, n, n)
local oldmeta = getmetatable ("").__index
getmetatable ("").__index =
  function (s, n)
    return string.sub (s, n, n)
  end

-- @func splitdir: split a directory path into components
-- Empty components are retained: the root directory becomes {"", ""}.
-- The same as Perl's File::Spec::splitdir
--   @param path: path
-- @returns
--   @param: path1, ..., pathn: path components
function io.splitdir (path)
  return string.split ("/", path)
end

-- @func catdir: concatenate directories into a path
-- The same as Perl's File::Spec::catdir
--   @param: path1, ..., pathn: path components
-- @returns
--   @param path: path
function io.catdir (...)
  local path = table.concat ({...}, "/")
  -- Suppress trailing / on non-root path
  return string.gsub (path, "(.)/$", "%1")
end
