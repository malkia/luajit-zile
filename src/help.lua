-- Self documentation facility functions
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

-- FIXME: Add apropos

Defun ("zile-version",
       {},
[[
Show the version of Zile that is running.
]],
  true,
  function ()
    minibuf_write (string.format ("%s of %s on %s", ZILE_VERSION_STRING, CONFIGURE_DATE, CONFIGURE_HOST))
  end
)

local function show_file (filename)
  if not exist_file (filename) then
    minibuf_error (string.format ("Unable to read file `%s'", filename))
    return leNIL
  end

  find_file (filename)
  cur_bp.readonly = true
  cur_bp.noundo = true
  cur_bp.needname = true
  cur_bp.nosave = true

  return leT
end

Defun ("view-emacs-FAQ",
       {},
[[
Display the Zile Frequently Asked Questions (FAQ) file.
]],
  true,
  function ()
    return show_file (PATH_DATA "/FAQ")
  end
)

local function write_function_description (name, doc)
  insert_string (string.format ("%s is %s built-in function in `C source code'.\n\n%s",
                                name,
                                get_function_interactive (name) and "an interactive" or "a",
                                doc))
end

Defun ("describe-function",
       {"string"},
[[
Display the full documentation of a function.
]],
  true,
  function (func)
    if not func then
      func = minibuf_read_function_name ("Describe function: ")
      if not func then
        return leNIL
      end
    end

    local doc = get_function_doc (func)
    if not doc then
      return leNIL
    else
      write_temp_buffer ("*Help*", true, write_function_description, func, doc)
    end

    return leT
  end
)

local function write_key_description (name, doc, binding)
  local interactive = get_function_interactive (name)
  assert (interactive ~= nil)

  insert_string (string.format ("%s runs the command %s, which is %s built-in\n" ..
                                "function in `C source code'.\n\n%s",
                              binding, name,
                              interactive and "an interactive" or "a",
                              doc))
end

Defun ("describe-key",
       {"string"},
[[
Display documentation of the command invoked by a key sequence.
]],
  true,
  function (keystr)
    local name, binding, keys
    if keystr then
      keys = keystrtovec (keystr)
      if not keys then
        return false
      end
      name = get_function_by_keys (keys)
      binding = keyvectostr (keys)
    else
      minibuf_write ("Describe key:")
      keys, name = get_key_sequence ()
      binding = keyvectostr (keys)

      if not name then
        minibuf_error (binding .. " is undefined")
        return false
      end
    end

    minibuf_write ("%s runs the command `%s'", binding, name)

    local doc = get_function_doc (name)
    if not doc then
      return false
    end
    write_temp_buffer ("*Help*", true, write_key_description, name, doc, binding)

    return true
  end
)

local function write_variable_description (name, curval, doc)
  insert_string (string.format ("%s is a variable defined in `C source code'.\n\n" ..
                                "Its value is %s\n\n%s",
                              name, curval, doc))
end

Defun ("describe-variable",
       {"string"},
[[
Display the full documentation of a variable.
]],
  true,
  function (name)
    local ok = leT

    if not name then
      name = minibuf_read_variable_name ("Describe variable: ")
    end

    if not name then
      ok = leNIL
    else
      local doc = main_vars[name].doc

      if not doc then
        ok = leNIL
      else
        write_temp_buffer ("*Help*", true,
                           write_variable_description,
                           name, get_variable (name), doc)
      end
    end
    return ok
  end
)
