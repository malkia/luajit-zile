-- Program invocation, startup and shutdown
--
-- Copyright (c) 2010, 2011 Free Software Foundation, Inc.
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

-- Derived constants
ZILE_VERSION_STRING = "GNU " .. PACKAGE_NAME .. " " .. VERSION

-- Runtime constants
-- The executable name
program_name = posix.basename (arg[0] or PACKAGE)


-- Main editor structures.

-- Undo delta types.
UNDO_REPLACE_BLOCK = 0  -- Replace a block of characters.
UNDO_START_SEQUENCE = 1 -- Start a multi operation sequence.
UNDO_END_SEQUENCE = 2   -- End a multi operation sequence.

-- Keyboard handling

GETKEY_DELAYED = 0001
GETKEY_UNFILTERED = 0002

-- Special value returned for invalid key codes, or when no key is pressed
KBD_NOKEY = -1

-- Key modifiers.
KBD_CTRL = 512
KBD_META = 1024

-- Common non-alphanumeric keys.
KBD_CANCEL = bit.bor (KBD_CTRL, string.byte ('g'))
KBD_TAB = 258
KBD_RET = 259
KBD_PGUP = 260
KBD_PGDN = 261
KBD_HOME = 262
KBD_END = 263
KBD_DEL = 264
KBD_BS = 265
KBD_INS = 266
KBD_LEFT = 267
KBD_RIGHT = 268
KBD_UP = 269
KBD_DOWN = 270
KBD_F1 = 272
KBD_F2 = 273
KBD_F3 = 274
KBD_F4 = 275
KBD_F5 = 276
KBD_F6 = 277
KBD_F7 = 278
KBD_F8 = 279
KBD_F9 = 280
KBD_F10 = 281
KBD_F11 = 282
KBD_F12 = 283


-- Miscellaneous stuff.

-- Global flags, stored in thisflag and lastflag.
FLAG_NEED_RESYNC    = 0x01 -- A resync is required.
FLAG_QUIT           = 0x02 -- The user has asked to quit.
FLAG_SET_UNIARG     = 0x04 -- The last command modified the universal arg variable `uniarg'.
FLAG_UNIARG_EMPTY   = 0x08 -- Current universal arg is just C-u's with no number.
FLAG_DEFINING_MACRO = 0x10 -- We are defining a macro.

-- Zile font codes
FONT_NORMAL = 0
FONT_REVERSE = 1

-- Default waitkey pause in ds
WAITKEY_DEFAULT = 20

-- The current window
cur_wp = nil
-- The first window in list
head_wp = nil

-- The current buffer
cur_bp = nil
-- The first buffer in list
head_bp = nil

-- The global editor flags.
thisflag = 0
lastflag = 0


ZILE_COPYRIGHT_STRING = "Copyright (C) 2010 Free Software Foundation, Inc."

local about_minibuf_str = "Welcome to " .. PACKAGE_NAME .. "!"

local about_splash_str = ZILE_VERSION_STRING .. [[

]] .. ZILE_COPYRIGHT_STRING .. [[

Type `C-x C-c' to exit ]] .. PACKAGE_NAME .. [[
Type `C-x u' to undo changes.
Type `C-g' at any time to quit the current operation.

`C-x' means hold the CTRL key while typing the character `x'.
`M-x' means hold the META or ALT key down while typing `x'.
If there is no META or ALT key, instead press and release
the ESC key and then type `x'.
Combinations like `C-x u' mean first press `C-x', then `u'.
]]

local function about_screen ()
  minibuf_write (about_minibuf_str)
  if not get_variable_bool ("inhibit-splash-screen") then
    show_splash_screen (about_splash_str)
    term_refresh ()
    waitkey (20 * 10)
  end
end

local function setup_main_screen ()
  local last_bp
  local c = 0

  local bp = head_bp
  while bp do
    -- Last buffer that isn't *scratch*.
    if bp.next and bp.next.next == nil then
      last_bp = bp
    end
    c = c + 1
    bp = bp.next
  end

  -- *scratch* and two files.
  if c == 3 then
    execute_function ("split-window")
    switch_to_buffer (last_bp)
    execute_function ("other-window")
  elseif c > 3 then
    -- More than two files.
    execute_function ("list-buffers")
  end
end

-- Documented options table
--
-- Documentation line: "doc", "DOCSTRING"
-- Option: "opt", long name, short name ('\0' for none), argument, argument docstring, docstring)
-- Action: "act", ARGUMENT, DOCSTRING
--
-- Options which take no argument have an optional_argument, so that,
-- as in Emacs, no argument is signalled as extraneous.

-- FIXME: Add -q
local options = {
  {"doc", "Initialization options:"},
  {"doc", ""},
  {"opt", "no-init-file", 'q', "optional", "", "do not load ~/." .. PACKAGE},
  {"opt", "funcall", 'f', "required", "FUNC", "call " .. PACKAGE_NAME .. " Lisp function FUNC with no arguments"},
  {"opt", "load", 'l', "required", "FILE", "load " .. PACKAGE_NAME .. " Lisp FILE using the load function"},
  {"opt", "help", '\0', "optional", "", "display this help message and exit"},
  {"opt", "version", '\0', "optional", "", "display version information and exit"},
  {"doc", ""},
  {"doc", "Action options:"},
  {"doc", ""},
  {"act", "FILE", "visit FILE using find-file"},
  {"act", "+LINE FILE", "visit FILE using find-file, then go to line LINE"},
}

-- Options table
local longopts = {}
for _, v in ipairs (options) do
  if v[1] == "opt" then
    table.insert (longopts, {v[2], v[4], string.byte (v[3])})
  end
end


local zarg = {}
local qflag = false

function process_args ()
  -- Leading `-' means process all arguments in order, treating
  -- non-options as arguments to an option with code 1
  -- Leading `:' so as to return ':' for a missing arg, not '?'
  for c, longindex, optind, optarg in posix.getopt_long (arg, "-:f:l:q", longopts) do
    local this_optind = optind > 0 and optind or 1
    local line = 1

    if c == 1 then -- Non-option (assume file name)
      longindex = 5
    elseif c == string.byte ('?') then -- Unknown option
      minibuf_error (string.format ("Unknown option `%s'", arg[this_optind]))
    elseif c == string.byte (':') then -- Missing argument
      io.stderr:write (string.format ("%s: Option `%s' requires an argument\n",
                                      program_name, arg[this_optind]))
      os.exit (1)
    elseif c == string.byte ('q') then
      longindex = 0
    elseif c == string.byte ('f') then
      longindex = 1
    elseif c == string.byte ('l') then
      longindex = 2
    end

    if longindex == 0 then
      qflag = true
    elseif longindex == 1 then
      table.insert (zarg, {'function', optarg})
    elseif longindex == 2 then
      table.insert (zarg, {'loadfile', optarg})
    elseif longindex == 3 then
      io.write ("Usage: " .. arg[0] .. " [OPTION-OR-FILENAME]...\n" ..
                "\n" ..
                "Run " .. PACKAGE_NAME .. ", the lightweight Emacs clone.\n" ..
                "\n")

      for _, v in ipairs (options) do
        if v[1] == "doc" then
          io.write (v[2] .. "\n")
        elseif v[1] == "opt" then
          local shortopt = string.format (", -%s", v[3])
          local buf = string.format ("--%s%s %s", v[2], v[3] ~= '\0' and shortopt or "", v[5])
          io.write (string.format ("%-24s%s\n", buf, v[6]))
        elseif v[1] == "act" then
          io.write (string.format ("%-24s%s\n", v[2], v[3]))
        end
      end

      io.write ("\n" ..
                "Report bugs to " .. PACKAGE_BUGREPORT .. ".\n")
      os.exit (0)
    elseif longindex == 4 then
      io.write (ZILE_VERSION_STRING .. "\n" ..
                ZILE_COPYRIGHT_STRING .. "\n" ..
                "GNU " .. PACKAGE_NAME .. " comes with ABSOLUTELY NO WARRANTY.\n" ..
                "You may redistribute copies of " .. PACKAGE_NAME .. "\n" ..
                "under the terms of the GNU General Public License.\n" ..
                "For more information about these matters, see the file named COPYING.\n")
      os.exit (0)
    elseif longindex == 5 then
      if optarg[1] == '+' then
        line = tonumber (optarg + 1, 10)
      else
        table.insert (zarg, {'file', optarg, line})
        line = 1
      end
    end
  end
end

local function segv_sig_handler (signo)
  io.stderr:write (program_name .. ": " .. PACKAGE_NAME ..
                   " crashed.  Please send a bug report to <" ..
                   PACKAGE_BUGREPORT .. ">.\r\n")
  zile_exit (true)
end

local function other_sig_handler (signo)
  io.stderr:write (program_name .. ": terminated with signal " .. tostring (signo) .. ".\r\n")
  zile_exit (false)
end

local function signal_init ()
  -- Set up signal handling
  posix.signal[posix.SIGSEGV] = segv_sig_handler
  posix.signal[posix.SIGBUS] = segv_sig_handler
  posix.signal[posix.SIGHUP] = other_sig_handler
  posix.signal[posix.SIGINT] = other_sig_handler
  posix.signal[posix.SIGTERM] = other_sig_handler
end

function main ()
  local scratch_bp

  signal_init ()

  process_args ()

  os.setlocale ("")

  term_init ()

  init_default_bindings ()

  -- Create the `*scratch*' buffer, so that initialisation commands
  -- that act on a buffer have something to act on.
  create_scratch_window ()
  scratch_bp = cur_bp
  insert_string (";; This buffer is for notes you don't want to save.\n;; If you want to create a file, visit that file with C-x C-f,\n;; then enter the text in that file's own buffer.\n\n")
  cur_bp.modified = false

  if not qflag then
    local s = os.getenv ("HOME")
    if s then
      lisp_loadfile (s .. "/." .. PACKAGE)
    end
  end

  -- Show the splash screen only if no files, function or load file is
  -- specified on the command line, and there has been no error.
  if not zarg and not minibuf_contents then
    about_screen ()
  end
  setup_main_screen ()

  -- Load files and load files and run functions given on the command line.
  local ok = true
  for i = 1, #zarg do
    local type, arg, line = zarg[i][1], zarg[i][2], zarg[i][3]

    if type == "function" then
      ok = function_exists (arg)
      if ok then
        ok = execute_function (arg, true) ~= leNIL
      else
        minibuf_error (string.format ("Function `%s' not defined", arg))
      end
    elseif type == "loadfile" then
      ok = lisp_loadfile (arg)
      if not ok then
        minibuf_error (string.format ("Cannot open load file: %s\n", arg))
      end
    elseif type == "file" then
      ok = find_file (arg)
      if ok then
        execute_function ("goto-line", line)
        lastflag = bit.bor (lastflag, FLAG_NEED_RESYNC)
      end
    end
    if bit.band (thisflag, FLAG_QUIT) ~= 0 then
      break
    end
  end

  lastflag = bit.bor (lastflag, FLAG_NEED_RESYNC)

  -- Reinitialise the scratch buffer to catch settings
  init_buffer (scratch_bp)

  -- Refresh minibuffer in case there was an error that couldn't be
  -- written during startup
  minibuf_refresh ()

  -- Run the main loop.
  while bit.band (thisflag, FLAG_QUIT) == 0 do
    if bit.band (lastflag, FLAG_NEED_RESYNC) ~= 0 then
      resync_redisplay (cur_wp)
    end
    term_redisplay ()
    term_refresh ()
    process_command ()
  end

  -- Tidy and close the terminal.
  term_finish ()
end
