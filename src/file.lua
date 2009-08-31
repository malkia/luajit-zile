-- Disk file handling
--
-- Copyright (c) 2009 Free Software Foundation, Inc.
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


-- This functions makes the passed path an absolute path:
--
--  * expands `~/' and `~name/' expressions;
--  * replaces `//' with `/' (restarting from the root directory);
--  * removes `..' and `.' entries.
--
-- Returns normalized path, or nil if a password entry could not be
-- read
function normalize_path (path)
  -- Prepend cwd if path is relative, and ensure trailing `/'
  if path[1] ~= "/" and path[1] ~= "~" then
    path = (posix.getcwd () or "") .. path
    path = string.gsub (path, "([^/])$", "%1/")
  end

  -- `//'
  path = string.gsub (path, "^.*//+", "/")

  -- Deal with `~', `~user', `..', `.'
  local comp = io.splitdir (path)
  local ncomp = {}
  for _, v in ipairs (comp) do
    if v == "~" then -- `~'
      local home = posix.getpasswd (nil, "dir")
      if home ~= nil then
        table.insert (ncomp, home)
      else
        return nil
      end
    else
      local user = string.match (v, "^~(.+)$")
      if user ~= nil then -- `~user'
        local home = posix.getpasswd (user, "dir")
        if passwd ~= nil then
          table.insert (ncomp, home)
        else
          return nil
        end
      elseif v == ".." then -- `..'
        table.remove (ncomp)
      elseif v ~= "." then -- not `.'
        table.insert (ncomp, v)
      end
    end
  end

  local npath = io.catdir (unpack (ncomp))
  -- Add back trailing slash if there was one originally and it would
  -- not be redundant (i.e. path is not "/")
  if path[-1] == "/" and npath[-1] ~= "/" then
    npath = npath .. "/"
  end
  return npath
end

-- Return a `~/foo' like path if the user is under his home directory,
-- else the unmodified path.
-- If the user's home directory cannot be read, nil is returned.
function compact_path (path)
  local home = posix.getpasswd (nil, "dir")
  -- If we cannot get the home directory, return error
  if home == nil then
    return nil
  end

  -- Replace `^/$HOME' (if found) with `~'.
  return string.gsub (path, "^" .. home, "~")
end
