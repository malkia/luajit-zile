-- run-lisp-tests
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
--
-- N.B. Tests that use execute-kbd-macro must note that keyboard input
-- is only evaluated once the script has finished running.

require "posix"

-- srcdir and builddir are defined in the environment for a build
local srcdir = os.getenv ("srcdir") or "."
local builddir = os.getenv ("builddir") or "."

local zile_pass = 0
local zile_fail = 0
local emacs_pass = 0
local emacs_fail = 0

-- If TERM is not set to a terminal type, choose a default
local TERM = os.getenv ("TERM")
if not TERM or TERM == "unknown" then
  os.setenv ("TERM", "vt100")
end

for _, name in ipairs (arg) do
  local test = string.gsub (posix.basename (name), "%.el$", "")
  local edit_file = io.catfile (builddir, test .. ".input")
  local args = {"--no-init-file", edit_file, "--load", io.catfile (srcdir, "lisp-tests", test .. ".el")}

  if os.getenv ("EMACS") then
    posix.system ("cp", io.catfile (srcdir, "lisp-tests", "test.input"), edit_file)
    posix.system ("chmod", "+w", edit_file)
    local status = posix.system (os.getenv ("EMACS"), "--quick", "--batch", unpack (args))
    if status == 0 then
      if posix.system ("diff", io.catfile (srcdir, "lisp-tests", test .. ".output"), edit_file) == 0 then
        emacs_pass = emacs_pass + 1
        posix.system ("rm", "-f", edit_file, edit_file .. "~")
      else
        print ("Emacs " .. test .. " failed to produce correct output")
        emacs_fail = emacs_fail + 1
      end
    else
      print ("Emacs " .. test .. " failed to run with error code " .. tostring (status))
      emacs_fail = emacs_fail + 1
    end
  end

  posix.system ("cp", io.catfile (srcdir, "lisp-tests", "test.input"), edit_file)
  posix.system ("chmod", "+w", edit_file)
  local status = posix.system (io.catfile (builddir, "zile"), unpack (args))
  if status == 0 then
    if posix.system ("diff", io.catfile (srcdir, "lisp-tests", test .. ".output"), edit_file) == 0 then
      zile_pass = zile_pass + 1
      posix.system ("rm", "-f", edit_file, edit_file .. "~")
    else
      print ("Zile " .. test .. " failed to produce correct output")
      zile_fail = zile_fail + 1
    end
  else
    print ("Zile " .. test .. " failed to run with error code " .. tostring (status))
    zile_fail = zile_fail + 1
  end
end

print (string.format ("Zile: %d pass(es) and %d failure(s)", zile_pass, zile_fail))
print (string.format ("Emacs: %d pass(es) and %d failure(s)", emacs_pass, emacs_fail))

os.exit (zile_fail + emacs_fail)
