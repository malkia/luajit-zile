-- Disk file handling
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


-- Formats of end-of-line
coding_eol_lf = "\n"
coding_eol_crlf = "\r\n"
coding_eol_cr = "\r"


function exist_file (filename)
  return posix.stat (filename) ~= nil
end

local function is_regular_file (filename)
  local st = posix.stat (filename)

  if st and st.type == "regular" then
    return true
  end
end

-- Return nonzero if file exists and can be written.
local function check_writable (filename)
  -- FIXME: Should use euidaccess
  return posix.access (filename, "w") >= 0
end

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
  if path[-1] == "/" and npath ~= "/" then
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

-- Return the current directory for the buffer.
local function get_buffer_dir ()
  local ret = ""
  if cur_bp.filename then
    -- If the current buffer has a filename, get the current directory
    -- name from it.
    ret = posix.dirname (cur_bp.filename)
  else -- Get the current directory name from the system.
    ret = posix.getcwd ()
  end
  if string.sub (ret, -1) ~= "/" then
    ret = ret .. "/"
  end
  return ret
end

Defun ("find-file",
       {},
[[
Edit the specified file.
Switch to a buffer visiting the file,
creating one if none already exists.
]],
  true,
  function ()
    local buf = get_buffer_dir ()
    local ms = minibuf_read_filename ("Find file: ", buf)
    local ok = leNIL

    if not ms then
      ok = execute_function ("keyboard-quit")
    elseif ms == "" then
      ok = bool_to_lisp (find_file (ms))
    end

    return ok
  end
)

Defun ("find-file-read-only",
       {},
[[
Edit the specified file but don't allow changes.
Like `find-file' but marks buffer as read-only.
Use @kbd{M-x toggle-read-only} to permit editing.
]],
  true,
  function ()
    local ok = excecute_function (find_file)
    if ok == leT then
      cur_bp.readonly = true
    end
  end
)

Defun ("find-alternate-file",
       {},
[[
Find the file specified by the user, select its buffer, kill previous buffer.
If the current buffer now contains an empty file that you just visited
(presumably by mistake), use this command to visit the file you really want.
]],
  true,
  function ()
    local buf = cur_bp.filename
    local base, ms, as

    if not buf then
      buf = get_buffer_dir ()
    else
      base = base_name (buf)
      ms = minibuf_read_filename ("Find alternate: ", buf, base)
    end

    local ok = leNIL
    if not ms then
      ok = execute_function ("keyboard-quit")
    elseif ms ~= "" and check_modified_buffer (cur_bp ()) then
      kill_buffer (cur_bp)
      ok = bool_to_lisp (find_file (ms))
    end

    return ok
  end
)

local function insert_file (filename)
  if not exist_file (filename) then
    minibuf_error (string.format ("Unable to read file `%s'", filename))
    return false
  end

  local h, err = io.open (filename, "r")
  if not h then
    minibuf_write ("%s: %s", filename, err)
    return false
  end

  local buf = h:read ("*a")
  h:close ()
  if #buf < 1 then
    return true
  end

  undo_save (UNDO_REPLACE_BLOCK, cur_bp.pt, 0, #buf)
  undo_nosave = true
  insert_string (buf)
  undo_nosave = false

  return true
end

Defun ("insert-file",
       {"string"},
[[
Insert contents of file FILENAME into buffer after point.
Set mark after the inserted text.
]],
  true,
  function (file)
    local ok = leT

    if warn_if_readonly_buffer () then
      return leNIL
    end

    if not file then
      local buf = get_buffer_dir ()
      file = minibuf_read_filename ("Insert file: ", buf)
      if not file then
        ok = execute_function ("keyboard-quit")
      end
    end

    if not file or file == "" or not insert_file (file) then
      ok = leNIL
    else
      set_mark_interactive ()
    end

    return ok
  end
)

-- Write buffer to given file name with given mode.
local function raw_write_to_disk (bp, filename, mode)
  local ret = true
  local h = io.open (filename, "w") -- FIXME: mode

  if not h then
    return false
  end

  -- Save the lines.
  local lp = bp.lines.next
  while lp ~= bp.lines do
    if not h:write (lp.text) then
      ret = false
      break
    end

    if lp.next ~= bp.lines then
      if not h:write (bp.eol) then
        ret = false
        break
      end
    end

    lp = lp.next
  end

  if not h:close () then
    ret = false
  end

  return ret
end

-- Create a backup filename according to user specified variables.
local function create_backup_filename (filename, backupdir)
  local res

  -- Prepend the backup directory path to the filename
  if backupdir then
    local buf = backupdir
    if buf[-1] ~= '/' then
      buf = buf .. '/'
      filename = gsub (filename, "/", "!")

      if not normalize_path (buf) then
        buf = nil
      end
      res = buf
    end
  else
    res = filename
  end

  return res .. "~"
end

-- Copy a file.
local function copy_file (source, dest)
  local ifd = io.open (source, "r")
  if not ifd then
    minibuf_error (string.format ("%s: unable to backup", source))
    return false
  end

  local tname = os.tmpname ()
  local ofd = io.open (tname, "w")
  if not ofd then
    ifd:close ()
    minibuf_error (string.format ("%s: unable to create backup", dest))
    return false
  end

  local written = ofd:write (ifd:read ("*a"))
  ifd:close ()
  ofd:close ()

  if not written then
    minibuf_error (string.format ("Unable to write to backup file `%s'", dest))
    return false
  end

  local st = posix.stat (source)

  -- Recover file permissions and ownership.
  if st then
    posix.chmod (tname, st.mode)
    posix.chown (tname, st.uid, st.gid)
  end

  if st then
    local ok, err = os.rename (tname, dest)
    if not ok then
      minibuf_error (string.format ("Cannot rename temporary file `%s'", err))
      os.remove (tname)
      stat = nil
    end
  elseif unlink (tname) == -1 then
    minibuf_error (string.format ("Cannot remove temporary file `%s'", err))
  end

  -- Recover file modification time.
  if st then
    -- FIXME: Correct this (download lposix sources! Suggest they be included in docs for Debian package)
    posix.utime (dest, st.atime, st.mtime)
  end

  return st ~= nil
end

-- Write the buffer contents to a file.
-- Create a backup file if specified by the user variables.
local function write_to_disk (bp, filename)
  local backup = get_variable_bool ("make-backup-files")
  local backupdir = get_variable_bool ("backup-directory") and get_variable ("backup-directory")

  -- Make backup of original file.
  if not bp.backup and backup then
    local h = io.open (filename, "r+")
    if h then
      h:close ()
      local bfilename = create_backup_filename (filename, backupdir)
      if bfilename and copy_file (filename, bfilename) then
        bp.backup = true
      else
        minibuf_error ("Cannot make backup file: %s", strerror (errno))
        waitkey (WAITKEY_DEFAULT)
      end
    end
  end

  local ret, err = raw_write_to_disk (bp, filename, "rw-rw-rw-")
  if not ret then
    if ret == -1 then
      minibuf_error (string.format ("Error writing `%s': %s", filename, err))
    else
      minibuf_error (string.format ("Error writing `%s'", filename))
    end
    return false
  end

  return true
end

local function write_buffer (bp, needname, confirm, name, prompt)
  local ans = true
  local ok = leT

  if needname then
    name = minibuf_read_filename (prompt, "")
    if not name then
      return execute_function ("keyboard-quit")
    end
    if name == "" then
      return leNIL
    end
    confirm = true
  end

  if confirm and exist_file (name) then
    ans = minibuf_read_yn (string.format ("File `%s' exists; overwrite? (y or n) ", name))
    if ans == -1 then
      execute_function ("keyboard-quit")
    elseif ans == false then
      minibuf_error ("Canceled")
    end
    if ans ~= true then
      ok = leNIL
    end
  end

  if ans == true then
    if name ~= bp.filename then
      set_buffer_names (bp, name)
    end
    bp.needname = false
    bp.temporary = false
    bp.nosave = false
    if write_to_disk (bp, name) then
      minibuf_write ("Wrote " .. name)
      bp.modified = false
      undo_set_unchanged (bp.last_undop)
    else
      ok = leNIL
    end
  end

  return ok
end

local function save_buffer (bp)
  if not bp.modified then
    minibuf_write ("(No changes need to be saved)")
    return leT
  else
    return write_buffer (bp, bp.needname, false, bp.filename, "File to save in: ")
  end
end

Defun ("save-buffer",
       {},
[[
Save current buffer in visited file if modified. By default, makes the
previous version into a backup file if this is the first save.
]],
  true,
  function ()
    return save_buffer (cur_bp)
  end
)

Defun ("write-file",
       {},
[[
Write current buffer into file @i{filename}.
This makes the buffer visit that file, and marks it as not modified.

Interactively, confirmation is required unless you supply a prefix argument.
]],
  true,
  function ()
    return write_buffer (cur_bp, true,
                         arglist ~= nil and bit.band (lastflag, FLAG_SET_UNIARG) == 0,
                         nil, "Write file: ")
  end
)

local function save_some_buffers ()
  local none_to_save = true
  local noask = false

  local bp = head_bp
  while bp do
    if bp.modified and not bp.nosave then
      local fname = get_buffer_filename_or_name (bp)

      none_to_save = false

      if noask then
        save_buffer (bp)
      else
        while true do
          minibuf_write (string.format ("Save file %s? (y, n, !, ., q) ", fname))
          local c = getkey ()
          minibuf_clear ()

          if c == KBD_CANCEL then -- C-g
            execute_function ("keyboard-quit")
            return false
          elseif c == string.byte ('q') then
            bp = nil
            break
          elseif c == string.byte ('.') then
            save_buffer (bp)
            return true
          elseif c == string.byte ('!') then
            noask = true
          end
          if c == string.byte ('!') or c == string.byte (' ') or c == string.byte ('y') then
            save_buffer (bp)
          end
          if c == string.byte ('!') or c == string.byte (' ') or c == string.byte ('y') or c == string.byte ('n') or c == KBD_RET or c == KBD_DEL then
            break
          else
            minibuf_error ("Please answer y, n, !, . or q.")
            waitkey (WAITKEY_DEFAULT)
          end
        end
      end
    end
    bp = bp.next
  end

  if none_to_save then
    minibuf_write ("(No files need saving)")
  end

  return true
end

Defun ("save-some-buffers",
       {},
[[
Save some modified file-visiting buffers.  Asks user about each one.
]],
  true,
  function ()
    return bool_to_lisp (save_some_buffers ())
  end
)

Defun ("save-buffers-kill-emacs",
       {},
[[
Offer to save each buffer, then kill this Zile process.
]],
  true,
  function ()
    if not save_some_buffers () then
      return leNIL
    end

    local bp = head_bp
    while bp do
      if bp.modified and not bp.needname then
        while true do
          local ans = minibuf_read_yesno ("Modified buffers exist; exit anyway? (yes or no) ")
          if ans == nil then
            return execute_function ("keyboard-quit")
          elseif not ans then
            return leNIL
          end
          break -- We have found a modified buffer, so stop.
        end
      end
      bp = bp.next
    end

    thisflag = bit.bor (thisflag, FLAG_QUIT)
  end
)

Defun ("cd",
       {},
[[
Make the user specified directory become the current buffer's default
directory.
]],
  true,
  function ()
    local buf = get_buffer_dir ()
    local ms = minibuf_read_filename ("Change default directory: ", buf)

    if not ms then
      return execute_function ("keyboard-quit")
    end

    if ms ~= "" then
      local st = posix.stat (ms)
      if not s or not s.type == "directory" then
        minibuf_error (string.format ("`%s' is not a directory", ms))
        return leNIL
      end
      if posix.chdir (ms) == -1 then
        minibuf_write ("%s: %s", ms, strerror (errno))
        return leNIL
      end
      return leT
    end

    return leNIL
  end
)

local function insert_lines (n, finish, last, from_lp)
  while n < finish do
    insert_string (from_lp.text)
    if n < last then
      insert_newline ()
    end
    n = n + 1
    from_lp = from_lp.next
  end
  return n
end

local function insert_buffer (bp)
  local old_next = bp.pt.p.next
  local old_cur_line = bp.pt.p.text
  local old_cur_n = bp.pt.n
  local old_lines = bp.last_line
  local size = calculate_buffer_size (bp)

  undo_save (UNDO_REPLACE_BLOCK, cur_bp.pt, 0, size)
  undo_nosave = true
  insert_lines (0, old_cur_n, old_lines, bp.lines.next)
  insert_string (old_cur_line)
  if old_cur_n < old_lines then
    insert_newline ()
  end
  insert_lines (old_cur_n + 1, old_lines, old_lines, old_next)
  undo_nosave = false
end

Defun ("insert-buffer",
       {"string"},
[[
Insert after point the contents of BUFFER.
Puts mark after the inserted text.
]],
  true,
  function (buffer)
    local ok = leT

    local def_bp = cur_bp.next or head_bp

    if warn_if_readonly_buffer () then
      return leNIL
    end

    if not buffer then
      local cp = make_buffer_completion ()
      buffer = minibuf_read_completion (string.format ("Insert buffer (default %s): ", def_bp.name), "", cp)
      if not buffer then
        ok = execute_function ("keyboard-quit")
      end
    end

    if ok == leT then
      local bp

      if buffer and buffer ~= "" then
        bp = find_buffer (buffer)
        if not bp then
          minibuf_error (string.format ("Buffer `%s' not found", buffer))
          ok = leNIL
        end
      else
        bp = def_bp
      end

      insert_buffer (bp)
      set_mark_interactive ()
    end

    return ok
  end
)

-- Maximum number of EOLs to check before deciding type.
local max_eol_check_count = 3
-- FIXME: The following should come from lposix
ENOENT = 2
BUFSIZ = 4096
-- Read the file contents into current buffer.
-- Return quietly if the file doesn't exist, or other error.
local function read_file (filename)
  local h, err = io.open (filename, "r")
  if h == nil then
    if posix.errno () ~= ENOENT then
      minibuf_write (string.format ("%s: %s", filename, err))
      cur_bp.readonly = true
    end
    return
  end

  if not check_writable (filename) then
    cur_bp.readonly = true
  end

  local lp = cur_bp.pt.p

  -- Read first chunk and determine EOL type.
  -- FIXME: Don't assume first EOL occurs in first chunk.
  local first_eol = true
  local this_eol_type
  local eol_len, total_eols = 0, 0
  local buf = h:read (BUFSIZ)
  if #buf > 0 then
    local i = 1
    while i <= #buf and total_eols < max_eol_check_count do
      if buf[i] == '\n' or buf[i] == '\r' then
        total_eols = total_eols + 1
        if buf[i] == '\n' then
          this_eol_type = coding_eol_lf
        elseif i == #buf or buf[i + 1] ~= '\n' then
          this_eol_type = coding_eol_cr
        else
          this_eol_type = coding_eol_crlf
          i = i + 1
        end

        if first_eol then
          cur_bp.eol = this_eol_type
          first_eol = false
        elseif cur_bp.eol ~= this_eol_type then
          -- This EOL is different from the last; arbitrarily choose LF.
          cur_bp.eol = coding_eol_lf
          break
        end
      end
      i = i + 1
    end

    -- Process this and subsequent chunks into lines.
    repeat
      local i = 1
      while i <= #buf do
        if cur_bp.eol ~= string.sub (buf, i, i + #cur_bp.eol - 1) then
          lp.text = lp.text .. buf[i]
          i = i + 1
        else
          lp = line_insert (lp, "")
          cur_bp.last_line = cur_bp.last_line + 1
          i = i + #cur_bp.eol
        end
      end
      buf = h:read (BUFSIZ)
    until not buf
  end

  lp.next = cur_bp.lines
  cur_bp.lines.prev = lp
  cur_bp.lines.next.p = cur_bp.pt

  h:close ()
end

function find_file (filename)
  local bp = head_bp
  while bp do
    if bp.filename == filename then
      switch_to_buffer (bp)
      return true
    end
    bp = bp.next
  end

  if exist_file (filename) and not is_regular_file (filename) then
    minibuf_error ("File exists but could not be read")
    return false
  end

  bp = buffer_new ()
  set_buffer_names (bp, filename)

  switch_to_buffer (bp)
  read_file (filename)

  thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)

  return true
end

-- Function called on unexpected error or Zile crash (SIGSEGV).
-- Attempts to save modified buffers.
-- If doabort is true, aborts to allow core dump generation;
-- otherwise, exit.
function zile_exit (doabort)
  io.stderr:write ("Trying to save modified buffers (if any)...\r\n")

  local bp = head_bp
  while bp do
    if bp.modified (bp) and not bp.nosave then
      local buf, as = ""
      local i
      local fname = bp.filename or bp.name
      buf = string.upper (fname .. PACKAGE .. "SAVE")
      io.stderr:write (string.format ("Saving %s...\r\n", buf))
      raw_write_to_disk (bp, buf, "rw-------")
    end
    bp = bp.next
  end

  if doabort then
    posix.abort ()
  else
    os.exit (2)
  end
end
