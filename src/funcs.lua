-- Miscellaneous Emacs functions
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

Defun ("keyboard-quit",
       {},
[[
Cancel current command.
]],
  true,
  function ()
    deactivate_mark ()
    minibuf_error ("Quit")
    return leNIL
  end
)

Defun ("suspend-emacs",
       {},
[[
Stop Zile and return to superior process.
]],
  true,
  function ()
    posix.raise (posix.SIGTSTP)
  end
)

Defun ("overwrite-mode",
       {"number"},
[[
Toggle overwrite mode.
With prefix argument @i{arg}, turn overwrite mode on if @i{arg} is positive,
otherwise turn it off.  In overwrite mode, printing characters typed
in replace existing text on a one-for-one basis, rather than pushing
it to the right.  At the end of a line, such characters extend the line.
Before a tab, such characters insert until the tab is filled in.
@kbd{C-q} still inserts characters in overwrite mode; this
is supposed to make it easier to insert characters when necessary.
]],
  true,
  function (arg)
    cur_bp.overwrite = arg and arg > 0 or not cur_bp.overwrite
    return true
  end
)

Defun ("toggle-read-only",
       {},
[[
Change whether this buffer is visiting its file read-only.
]],
  true,
  function ()
    cur_bp.readonly = not cur_bp.readonly
  end
)

Defun ("auto-fill-mode",
       {},
[[
Toggle Auto Fill mode.
In Auto Fill mode, inserting a space at a column beyond `fill-column'
automatically breaks the line at a previous space.
]],
  true,
  function ()
    cur_bp.autofill = not cur_bp.autofill
  end
)

Defun ("exchange-point-and-mark",
       {},
[[
Put the mark where point is now, and point where the mark is now.
]],
  true,
  function ()
    if not cur_bp.mark then
      minibuf_error ("No mark set in this buffer")
      return leNIL
    end

    local tmp = table.clone (cur_bp.pt)
    cur_bp.pt = table.clone (cur_bp.mark.pt)
    cur_bp.mark.pt = tmp

    -- In transient-mark-mode we must reactivate the mark.
    if get_variable_bool ("transient-mark-mode") then
      activate_mark ()
    end

    thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)
  end
)

Defun ("transient-mark-mode",
       {"number"},
[[
Toggle Transient Mark mode.
With arg, turn Transient Mark mode on if arg is positive, off otherwise.
]],
  true,
  function (n)
    if not n and bit.band (lastflag, FLAG_SET_UNIARG) == 0 then
      set_variable ("transient-mark-mode", get_variable_bool ("transient-mark-mode") and "nil" or "t")
    elseif not n then
      n = get_variable ("current-prefix-arg")
    end
    if n then
      set_variable ("transient-mark-mode", n > 0 and "t" or "nil")
    end

    activate_mark ()
  end
)

function write_temp_buffer (name, show, func, ...)
  local old_wp = cur_wp
  local old_bp = cur_bp

  -- Popup a window with the buffer "name".
  local wp = find_window (name)
  if show and wp then
    set_current_window (wp)
  else
    local bp = find_buffer (name)
    if show then
      set_current_window (popup_window ())
    end
    if bp == nil then
      bp = buffer_new ()
      bp.name = name
    end
    switch_to_buffer (bp)
  end

  -- Remove the contents of that buffer.
  local new_bp = buffer_new ()
  new_bp.name = cur_bp.name
  kill_buffer (cur_bp)
  cur_bp = new_bp
  cur_wp.bp = cur_bp

  -- Make the buffer a temporary one.
  cur_bp.needname = true
  cur_bp.noundo = true
  cur_bp.nosave = true
  set_temporary_buffer (cur_bp)

  -- Use the "callback" routine.
  func (...)

  gotobob ()
  cur_bp.readonly = true
  cur_bp.modified = false

  -- Restore old current window.
  set_current_window (old_wp)

  -- If we're not showing the new buffer, switch back to the old one.
  if not show then
    switch_to_buffer (old_bp)
  end
end

Defun ("universal-argument",
       {},
[[
Begin a numeric argument for the following command.
Digits or minus sign following @kbd{C-u} make up the numeric argument.
@kbd{C-u} following the digits or minus sign ends the argument.
@kbd{C-u} without digits or minus sign provides 4 as argument.
Repeating @kbd{C-u} without digits or minus sign multiplies the argument
by 4 each time.
]],
  true,
  function ()
    local ok = leT

    -- Need to process key used to invoke universal-argument.
    pushkey (lastkey ())

    thisflag = bit.bor (thisflag, FLAG_UNIARG_EMPTY)

    local i = 0
    local arg = 1
    local sgn = 1
    local as = ""
    while true do
      as = as .. '-' -- Add the `-' character.
      local key = do_binding_completion (as)
      as = string.sub (as, 1, -2) -- Remove the `-' character.

      -- Cancelled.
      if key == KBD_CANCEL then
        ok = execute_function ("keyboard-quit")
        break
      -- Digit pressed.
      elseif string.match (string.char (bit.band (key, 0xff)), "%d") then
        local digit = bit.band (key, 0xff) - string.byte ('0')
        thisflag = bit.band (thisflag, bit.bnot (FLAG_UNIARG_EMPTY))

        if bit.band (key, KBD_META) ~= 0 then
          as = as .. "ESC"
        end

        as = as .. string.format (" %d", digit)

        if i == 0 then
          arg = digit
        else
          arg = arg * 10 + digit
        end

        i = i + 1
      elseif key == bit.bor (KBD_CTRL, string.byte ('u')) then
        as = as .. "C-u"
        if i == 0 then
          arg = arg * 4
        else
          break
        end
      elseif key == string.byte ('-') and i == 0 then
        if sgn > 0 then
          sgn = -sgn
          as = as .. " -"
          -- The default negative arg is -1, not -4.
          arg = 1
          thisflag = bit.band (thisflag, bit.bnot (FLAG_UNIARG_EMPTY))
        end
      else
        ungetkey (key)
        break
      end
    end

    if ok == leT then
      set_variable ("current-prefix-arg", tostring (arg * sgn))
      thisflag = bit.bor (thisflag, FLAG_SET_UNIARG)
      minibuf_clear ()
    end

    return ok
  end
)

local function print_buf (old_bp, bp)
  if bp.name[1] == ' ' then
    return
  end

  insert_string (string.format ("%s%s%s %-19s %6u  %-17s",
                                old_bp == bp and '.' or ' ',
                                bp.readonly and '%' or ' ',
                                bp.modified and '*' or ' ',
                                bp.name, calculate_buffer_size (bp), "Fundamental"))
  if bp.filename then
    insert_string (compact_path (bp.filename))
  end
  insert_newline ()
end

local function write_buffers_list (old_wp)
  -- FIXME: Underline next line properly.
  insert_string ("CRM Buffer                Size  Mode             File\n")
  insert_string ("--- ------                ----  ----             ----\n")

  -- Print buffers.
  local bp = old_wp.bp
  repeat
    -- Print all buffers except this one (the *Buffer List*).
    if cur_bp ~= bp then
      print_buf (old_wp.bp, bp)
    end
    bp = bp.next
    if not bp then
      bp = head_bp
    end
  until bp == old_wp.bp
end

Defun ("list-buffers",
       {},
[[
Display a list of names of existing buffers.
The list is displayed in a buffer named `*Buffer List*'.
Note that buffers with names starting with spaces are omitted.

@itemize -
The @samp{M} column contains a @samp{*} for buffers that are modified.
The @samp{R} column contains a @samp{%} for buffers that are read-only.
@end itemize
]],
  true,
  function ()
    write_temp_buffer ("*Buffer List*", true, write_buffers_list, cur_wp)
  end
)

function set_mark_interactive ()
  set_mark ()
  minibuf_write ("Mark set")
end

Defun ("set-mark",
       {},
[[
Set this buffer's mark to point.
]],
  false,
  function ()
    set_mark_interactive ()
    activate_mark ()
  end
)

Defun ("set-mark-command",
       {},
[[
Set the mark where point is.
]],
  true,
  function ()
    execute_function ("set-mark")
  end
)

Defun ("set-fill-column",
       {"number"},
[[
Set `fill-column' to specified argument.
Use C-u followed by a number to specify a column.
Just C-u as argument means to use the current column.
]],
  true,
  function (n)
    if not n and interactive then
      if bit.band (lastflag, FLAG_SET_UNIARG) ~= 0 then
        n = get_variable_number ("current-prefix-arg")
      else
        n = minibuf_read_number (string.format ("Set fill-column to (default %d): ", cur_bp.pt.o))
        if not n then -- cancelled
          return leNIL
        elseif n == "" then
          n = cur_bp.pt.o
        end
      end
    end

    if not n then
      minibuf_error ("set-fill-column requires an explicit argument")
      return leNIL
    end

    minibuf_write (string.format ("Fill column set to %d (was %d)", n, get_variable_number ("fill-column")))
    set_variable ("fill-column", tostring (n))
    return leT
  end
)

Defun ("quoted-insert",
       {},
[[
Read next input character and insert it.
This is useful for inserting control characters.
]],
  true,
  function ()
    minibuf_write ("C-q-")
    local c = xgetkey (GETKEY_UNFILTERED, 0)
    insert_char_in_insert_mode (string.char (c))
    minibuf_clear ()
  end
)

Defun ("fill-paragraph",
       {},
[[
Fill paragraph at or after point.
]],
  true,
  function ()
    local m = point_marker ()

    undo_save (UNDO_START_SEQUENCE, cur_bp.pt, 0, 0)

    execute_function ("forward-paragraph")
    local finish = cur_bp.pt.n
    if is_empty_line () then
      finish = finish - 1
    end

    execute_function ("backward-paragraph")
    local start = cur_bp.pt.n
    if is_empty_line () then -- Move to next line if between two paragraphs.
      next_line ()
      start = start + 1
    end

    for i = start, finish - 1 do
      execute_function ("end-of-line")
      delete_char ()
      execute_function ("just-one-space")
    end

    execute_function ("end-of-line")
    while get_goalc () > get_variable_number ("fill-column") + 1 and fill_break_line () do end

    cur_bp.pt = table.clone (m.pt)
    unchain_marker (m)

    undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)
  end
)

local function pipe_command (cmd, tempfile, insert, replace)
  local cmdline = string.format ("%s 2>&1 <%s", cmd, tempfile)
  local pipe = io.popen (cmdline, "r")
  if not pipe then
    minibuf_error ("Cannot open pipe to process")
    return false
  end

  local out = pipe:read ("*a")
  pipe:close ()
  local eol = string.find (out, "\n")
  local more_than_one_line = false
  if eol and eol ~= #out then
    more_than_one_line = true
  end

  if #out == 0 then
    minibuf_write ("(Shell command succeeded with no output)")
  else
    if insert then
      if replace then
        undo_save (UNDO_START_SEQUENCE, cur_bp.pt, 0, 0)
      end
      execute_function ("delete-region")
      insert_string (out)
      if replace then
        undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)
      end
    else
      write_temp_buffer ("*Shell Command Output*", more_than_one_line, insert_string, out)
      if not more_than_one_line then
        minibuf_write (out)
      end
    end
  end

  return true
end

local function minibuf_read_shell_command ()
  local ms = minibuf_read ("Shell command: ", "")

  if not ms then
    execute_function ("keyboard-quit")
    return
  end
  if ms == "" then
    return
  end

  return ms
end

Defun ("shell-command",
       {"string", "boolean"},
[[
Execute string @i{command} in inferior shell; display output, if any.
With prefix argument, insert the command's output at point.

Command is executed synchronously.  The output appears in the buffer
`*Shell Command Output*'.  If the output is short enough to display
in the echo area, it is shown there, but it is nonetheless available
in buffer `*Shell Command Output*' even though that buffer is not
automatically displayed.

The optional second argument @i{output-buffer}, if non-nil,
says to insert the output in the current buffer.
]],
  true,
  function (cmd, insert)
    if not cmd then
      cmd = minibuf_read_shell_command ()
    end
    if not insert then
      insert = bit.band (lastflag, FLAG_SET_UNIARG)
    end

    if cmd then
      return pipe_command (cmd, "/dev/null", insert, false)
    end
    return true
  end
)

-- The `start' and `end' arguments are fake, hence their string type,
-- so they can be ignored.
Defun ("shell-command-on-region",
       {"string", "string", "string", "boolean"},
[[
Execute string command in inferior shell with region as input.
Normally display output (if any) in temp buffer `*Shell Command Output*'
Prefix arg means replace the region with it.  Return the exit code of
command.

If the command generates output, the output may be displayed
in the echo area or in a buffer.
If the output is short enough to display in the echo area, it is shown
there.  Otherwise it is displayed in the buffer `*Shell Command Output*'.
The output is available in that buffer in both cases.
]],
  true,
  function (start, finish, cmd, insert)
    local ok = leT

    if not cmd then
      cmd = minibuf_read_shell_command ()
    end
    if not insert then
      insert = bit.band (lastflag, FLAG_SET_UNIARG)
    end

    if cmd then
      local rp = region_new ()

      if not calculate_the_region (rp) then
        ok = leNIL
      else
        local tempfile = os.tmpname ()
        local fd = io.open (tempfile, "w")

        if not fd then
          minibuf_error ("Cannot open temporary file")
          ok = leNIL
        else
          local as = copy_text_block (rp.start, rp.size)
          local written, err = fd:write (as)

          if not written then
            minibuf_error ("Error writing to temporary file: " .. err)
            ok = leNIL
          else
            ok = bool_to_lisp (pipe_command (cmd, tempfile, insert, true))
          end

          fd:close ()
          os.remove (tempfile)
        end
      end
    end
  end
)

Defun ("delete-region",
       {},
[[
Delete the text between point and mark.
]],
  true,
  function ()
    local rp = region_new ()

    if not calculate_the_region (rp) or not delete_region (rp) then
      return leNIL
    end
    deactivate_mark ()
    return leT
  end
)

Defun ("delete-blank-lines",
       {},
[[
On blank line, delete all surrounding blank lines, leaving just one.
On isolated blank line, delete that one.
On nonblank line, delete any immediately following blank lines.
]],
  true,
  function ()
    local m = point_marker ()
    local seq_started = false

    -- Delete any immediately following blank lines.
    if next_line () then
      if is_blank_line () then
        push_mark ()
        execute_function ("beginning-of-line")
        set_mark ()
        activate_mark ()
        while execute_function ("forward-line") == leT and is_blank_line () do end
        seq_started = true
        undo_save (UNDO_START_SEQUENCE, m.pt, 0, 0)
        execute_function ("delete-region")
        pop_mark ()
      end
      previous_line ()
    end

    -- Delete any immediately preceding blank lines.
    if is_blank_line () then
      local forward = true
      push_mark ()
      execute_function ("beginning-of-line")
      set_mark ()
      activate_mark ()
      repeat
        if not execute_function ("forward-line", -1, true) then
          forward = false
          break
        end
      until not is_blank_line ()
      if forward then
        execute_function ("forward-line")
      end
      if cur_bp.pt.p ~= m.pt.p then
        if not seq_started then
          seq_started = true
          undo_save (UNDO_START_SEQUENCE, m.pt, 0, 0)
        end
        execute_function ("delete-region")
      end
      pop_mark ()
    end

    -- Isolated blank line, delete that one.
    if not seq_started and is_blank_line () then
      push_mark ()
      execute_function ("beginning-of-line")
      set_mark ()
      activate_mark ()
      execute_function ("forward-line")
      execute_function ("delete-region") -- Just one action, without a sequence.
      pop_mark ()
    end

    cur_bp.pt = table.clone (m.pt)

    if seq_started then
      undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)
    end

    unchain_marker (m)
    deactivate_mark ()
  end
)

Defun ("forward-line",
       {"number"},
[[
Move N lines forward (backward if N is negative).
Precisely, if point is on line I, move to the start of line I + N.
]],
  true,
  function (n)
    n = n or get_variable_number ("current-prefix-arg")
    if n ~= 0 then
      execute_function ("beginning-of-line")
      return execute_with_uniarg (false, n, next_line, previous_line)
    end
    return false
  end
)

local function move_paragraph (uniarg, forward, backward, line_extremum)
  if uniarg < 0 then
    uniarg = -uniarg
    forward = backward
  end

  for i = uniarg, 1, -1 do
    repeat until not is_empty_line () or not forward ()
    repeat until is_empty_line () or not forward ()
  end

  if is_empty_line () then
    execute_function ("beginning-of-line")
  else
    execute_function (line_extremum, false)
  end
  return leT
end

Defun ("backward-paragraph",
       {"number"},
[[
Move backward to start of paragraph.  With argument N, do it N times.
]],
  true,
  function (n)
    return move_paragraph (n or 1, previous_line, next_line, "beginning-of-line")
  end
)

Defun ("forward-paragraph",
       {"number"},
[[
Move forward to end of paragraph.  With argument N, do it N times.
]],
  true,
  function (n)
    return move_paragraph (n or 1, next_line, previous_line, "end-of-line")
  end
)


-- Move through balanced expressions (sexp)
local function move_sexp (dir)
  local gotsexp = false
  local level = 0
  local double_quote = dir < 0
  local single_quote = dir < 0

  local function issexpchar (c)
    return string.match (c, "[%w$_]")
  end

  local function isopenbracketchar (c)
    return (c == '(') or (c == '[') or ( c== '{') or ((c == '\"') and not double_quote) or ((c == '\'') and not single_quote)
  end

  local function isclosebracketchar (c)
    return (c == ')') or (c == ']') or (c == '}') or ((c == '\"') and double_quote) or ((c == '\'') and single_quote)
  end

  local function issexpseparator (c)
    return isopenbracketchar (c) or isclosebracketchar (c)
  end

  local function precedingquotedquote (c)
    return c == '\\' and cur_bp.pt.o + 1 < #cur_bp.pt.p.text and
      (cur_bp.pt.p.text[cur_bp.pt.o + 1 + 1] == '\"' or cur_bp.pt.p.text[cur_bp.pt.o + 1 + 1] == '\'')
  end

  local function followingquotedquote (c)
    return c == '\\' and cur_bp.pt.o + 1 < #cur_bp.pt.p.text and
      (cur_bp.pt.p.text[cur_bp.pt.o + 1 + 1] == '\"' or cur_bp.pt.p.text[cur_bp.pt.o + 1 + 1] == '\'')
  end

  while true do
    while not (dir > 0 and eolp or bolp) () do
      local c = (dir > 0 and following_char or preceding_char) ()

      -- Skip quotes that aren't sexp separators.
      if (dir > 0 and precedingquotedquote or followingquotedquote) (c) then
        pt = cur_bp.pt
        pt.o = pt.o + dir
        c = 'a' -- Treat ' and " like word chars.
      end

      if (dir > 0 and isopenbracketchar or isclosebracketchar) (c) then
        if level == 0 and gotsexp then
          return true
        end

        level = level + 1
        gotsexp = true
        if c == '\"' then
          double_quote = not double_quote
        end
        if c == '\'' then
          single_quote = not single_quote
        end
      elseif (dir > 0 and isclosebracketchar or isopenbracketchar) (c) then
        if level == 0 and gotsexp then
          return true
        end

        level = level - 1
        gotsexp = true
        if c == '\"' then
          double_quote = not double_quote
        end
        if c == '\'' then
          single_quote = not single_quote
        end
        if level < 0 then
          minibuf_error ("Scan error: \"Containing expression ends prematurely\"")
          return false
        end
      end

      cur_bp.pt.o = cur_bp.pt.o + dir

      if not issexpchar (c) then
        if gotsexp and level == 0 then
          if not issexpseparator (c) then
            cur_bp.pt.o = cur_bp.pt.o - dir
          end
          return true
        end
      else
        gotsexp = true
      end
    end
    if gotsexp and level == 0 then
      return true
    end
    if not (dir > 0 and next_line or previous_line) () then
      if level ~= 0 then
        minibuf_error ("Scan error: \"Unbalanced parentheses\"")
      end
      return false
    end
    cur_bp.pt.o = dir > 0 and 0 or #cur_bp.pt.p.text
  end
end

local function forward_sexp ()
  return move_sexp (1)
end

local function backward_sexp ()
  return move_sexp (-1)
end

Defun ("forward-sexp",
       {"number"},
[[
Move forward across one balanced expression (sexp).
With argument, do it that many times.  Negative arg -N means
move backward across N balanced expressions.
]],
  true,
  function (n)
    return execute_with_uniarg (false, n, forward_sexp, backward_sexp)
  end
)

Defun ("backward-sexp",
       {"number"},
[[
Move backward across one balanced expression (sexp).
With argument, do it that many times.  Negative arg -N means
move forward across N balanced expressions.
]],
  true,
  function (n)
    return execute_with_uniarg (false, n, backward_sexp, forward_sexp)
  end
)

local function mark (uniarg, func)
  execute_function ("set-mark")
  local ret = execute_function (func, uniarg, true)
  if ret == leT then
    execute_function ("exchange-point-and-mark")
  end
  return ret
end

Defun ("mark-word",
       {"number"},
[[
Set mark argument words away from point.
]],
  true,
  function (n)
    return mark (n, "forward-word")
  end
)

Defun ("mark-sexp",
       {"number"},
[[
Set mark @i{arg} sexps from point.
The place mark goes is the same place @kbd{C-M-f} would
move to with the same argument.
]],
  true,
  function (n)
    return mark (n, "forward-sexp")
  end
)

Defun ("mark-paragraph",
       {},
[[
Put point at beginning of this paragraph, mark at end.
The paragraph marked is the one that contains point or follows point.
]],
  true,
  function ()
    if _last_command == "mark-paragraph" then
      execute_function ("exchange-point-and-mark")
      execute_function ("forward-paragraph")
      execute_function ("exchange-point-and-mark")
    else
      execute_function ("forward-paragraph")
      execute_function ("set-mark")
      execute_function ("backward-paragraph")
    end
  end
)

Defun ("mark-whole-buffer",
       {},
[[
Put point at beginning and mark at end of buffer.
]],
  true,
  function ()
    gotoeob ()
    execute_function ("set-mark-command")
    gotobob ()
  end
)


-- Compact the spaces into tabulations according to the `tw' tab width.
local function tabify_string (src, scol, tw)
  local dest = ""
  local dcol = scol

  for i = 1, #src do
    if src[i] == ' ' then
      dcol = dcol + 1
    elseif src[i] == '\t' then
      dcol = dcol + tw
      dcol = dcol - dcol % tw
    else
      while ((scol + tw) - (scol + tw) % tw) <= dcol and scol ~= dcol - 1 do
        dest = dest .. '\t'
        scol = scol + tw
        scol = scol - scol % tw
      end
      while scol < dcol do
        dest = dest .. ' '
        scol = scol + 1
      end
      dest = dest .. src[i]
      scol = scol + 1
      dcol = dcol + 1
    end
  end

  return dest
end

-- Expand the tabulations into spaces according to the `tw' tab width.
-- The output buffer should be big enough to contain the expanded string,
-- i.e. strlen (src) * tw + 1.
local function untabify_string (src, scol, tw)
  local col = scol
  local dest = ""

  for i = 1, #src do
    if src[i] == '\t' then
      repeat
        dest = dest .. ' '
        col = col + 1
      until col % tw == 0
    else
      dest = dest .. src[i]
      col = col + 1
    end
  end

  return dest
end

local function edit_tab_line (lp, lineno, offset, size, action)
  if size == 0 then
    return
  end

  -- Get offset's column.
  local t = tab_width (cur_bp)
  local col = 0
  for i = 1, offset do
    if lp.text[i] == '\t' then
      col = bit.bor (col, t - 1)
    end
    col = col + 1
  end

  -- Call un/tabify function.
  local src = string.sub (lp.text, offset + 1, offset + size)
  local dest = action (src, col, t)
  if src ~= dest then
    undo_save (UNDO_REPLACE_BLOCK, make_point (lineno, offset), size, #dest)
    line_replace_text (lp, offset, size, dest, false)
  end
end

function edit_tab_region (action)
  local rp = region_new ()

  if warn_if_readonly_buffer () or not calculate_the_region (rp) then
    return leNIL
  end

  if rp.size ~= 0 then
    local m = point_marker ()

    undo_save (UNDO_START_SEQUENCE, m.pt, 0, 0)
    local lp = rp.start.p
    for lineno = rp.start.n, rp.finish.n do
      -- First line.
      if lineno == rp.start.n then
        if lineno == rp.finish.n then -- Region on a sole line.
          edit_tab_line (lp, lineno, rp.start.o, rp.size, action)
        else -- Region is multi-line.
          edit_tab_line (lp, lineno, rp.start.o, #lp.text - rp.start.o, action)
        end
      elseif lineno == rp.finish.n then -- Last line of multi-line region.
        edit_tab_line (lp, lineno, 0, rp.finish.o, action)
      else -- Middle line of multi-line region.
        edit_tab_line (lp, lineno, 0, #lp.text, action)
      end
      if lineno == rp.finish.n then -- Done?
        break
      end
      lp = lp.next
    end
    cur_bp.pt = table.clone (m.pt)
    undo_save (UNDO_END_SEQUENCE, m.pt, 0, 0)
    unchain_marker (m)
    deactivate_mark ()
  end

  return leT
end

Defun ("tabify",
       {},
[[
Convert multiple spaces in region to tabs when possible.
A group of spaces is partially replaced by tabs
when this can be done without changing the column they end at.
The variable @samp{tab-width} controls the spacing of tab stops.
]],
  true,
  function ()
    return edit_tab_region (tabify_string)
  end
)

Defun ("untabify",
       {},
[[
Convert all tabs in region to multiple spaces, preserving columns.
The variable @samp{tab-width} controls the spacing of tab stops.
]],
  true,
  function ()
    return edit_tab_region (untabify_string)
  end
)

Defun ("back-to-indentation",
       {},
[[
Move point to the first non-whitespace character on this line.
]],
  true,
  function ()
    cur_bp.pt = line_beginning_position (1)
    while not eolp () and string.match (following_char (), "%s") do
      forward_char ()
    end
  end
)


-- Move through words
local function iswordchar (c)
  return (string.match (c, "%w") ~= nil) or c == '$'
end

local function move_word (dir, next_char, move_char, at_extreme)
  local gotword = false
  while true do
    while not at_extreme () do
      if not iswordchar (next_char ()) then
        if gotword then
          return true
        end
      else
        gotword = true
      end
      cur_bp.pt.o = cur_bp.pt.o + dir
    end
    if gotword then
      return true
    end
    if not move_char () then
      break
    end
  end
  return false
end

local function forward_word ()
  return move_word (1, following_char, forward_char, eolp)
end

local function backward_word ()
  return move_word (-1, preceding_char, backward_char, bolp)
end

Defun ("forward-word",
       {"number"},
[[
Move point forward one word (backward if the argument is negative).
With argument, do this that many times.
]],
  true,
  function (n)
    return execute_with_uniarg (false, n, forward_word, backward_word)
  end
)

Defun ("backward-word",
       {"number"},
[[
Move backward until encountering the end of a word (forward if the
argument is negative).
With argument, do this that many times.
]],
  true,
  function (n)
    return execute_with_uniarg (false, n, backward_word, forward_word)
  end
)

local function setcase_word (rcase)
  if not iswordchar (following_char ()) then
    if not forward_word () or not backward_word () then
      return false
    end
  end

  local as = ""
  for i = cur_bp.pt.o, #cur_bp.pt.p.text do
    if iswordchar (cur_bp.pt.p.text[i + 1]) then
      as = as .. cur_bp.pt.p.text[i + 1]
    else
      break
    end
  end

  if #as > 0 then
    undo_save (UNDO_REPLACE_BLOCK, cur_bp.pt, #as, #as)
    cur_bp.pt.p.text = string.sub (cur_bp.pt.p.text, 1, cur_bp.pt.o) ..
      recase (as, rcase) ..
      string.sub (cur_bp.pt.p.text, cur_bp.pt.o + 1 + #as)
  end

  forward_word ()
  cur_bp.modified = true

  return true
end

Defun ("downcase-word",
       {"number"},
[[
Convert following word (or @i{arg} words) to lower case, moving over.
]],
  true,
  function (arg)
    return execute_with_uniarg (true, arg, function () return setcase_word ("lower") end)
  end
)

Defun ("upcase-word",
       {"number"},
[[
Convert following word (or @i{arg} words) to upper case, moving over.
]],
  true,
  function (arg)
    return execute_with_uniarg (true, arg, function () return setcase_word ("upper") end)
  end
)

Defun ("capitalize-word",
       {"number"},
[[
Capitalize the following word (or @i{arg} words), moving over.
This gives the word(s) a first character in upper case
and the rest lower case.
]],
  true,
  function (arg)
    return execute_with_uniarg (true, arg, function () return setcase_word ("capitalized") end)
  end
)

-- Set the region case.
local function setcase_region (func)
  local rp = region_new ()

  if warn_if_readonly_buffer () or not calculate_the_region (rp) then
    return leNIL
  end

  undo_save (UNDO_REPLACE_BLOCK, rp.start, rp.size, rp.size)

  local lp = rp.start.p
  local i = rp.start.o
  for _ = rp.size, 1, -1 do
    if i < #lp.text then
      lp.text = string.sub (lp.text, 1, i) .. func (lp.text[i + 1]) .. string.sub (lp.text, i + 2)
      i = i + 1
    else
      lp = lp.next
      i = 0
    end
  end

  cur_bp.modified = true

  return leT
end

Defun ("upcase-region",
       {},
[[
Convert the region to upper case.
]],
  true,
  function ()
    return setcase_region (string.upper)
  end
)

Defun ("downcase-region",
       {},
[[
Convert the region to lower case.
]],
  true,
  function ()
    return setcase_region (string.lower)
  end
)


-- Transpose functions
local function region_to_string ()
  local rp = region_new ()
  activate_mark ()
  calculate_the_region (rp)
  return copy_text_block (rp.start, rp.size)
end

local function transpose_subr (forward_func, backward_func)
  local p0 = point_marker ()

  -- For transpose-chars.
  if forward_func == forward_char and eolp () then
    backward_func ()
  end
  -- For transpose-lines.
  if forward_func == next_line and cur_bp.pt.n == 0 then
    forward_func ()
  end

  -- Backward.
  if not backward_func () then
    minibuf_error ("Beginning of buffer")
    unchain_marker (p0)
    return false
  end

  -- Save mark.
  push_mark ()

  -- Mark the beginning of first string.
  set_mark ()
  local m1 = point_marker ()

  -- Check to make sure we can go forwards twice.
  if not forward_func () or not forward_func () then
    if forward_func == next_line then
      -- Add an empty line.
      execute_function ("end-of-line")
      execute_function ("newline")
    else
      pop_mark ()
      goto_point (m1.pt)
      minibuf_error ("End of buffer")

      unchain_marker (p0)
      unchain_marker (m1)
      return false
    end
  end

  goto_point (m1.pt)

  -- Forward.
  forward_func ()

  -- Save and delete 1st marked region.
  local as1 = region_to_string ()

  unchain_marker (p0)
  execute_function ("delete-region")

  -- Forward.
  forward_func ()

  -- For transpose-lines.
  local m2, as2
  if forward_func == next_line then
    m2 = point_marker ()
  else
    -- Mark the end of second string.
    set_mark ()

    -- Backward.
    backward_func ()
    m2 = point_marker ()

    -- Save and delete 2nd marked region.
    as2 = region_to_string ()
    execute_function ("delete-region")
  end

  -- Insert the first string.
  goto_point (m2.pt)
  unchain_marker (m2)
  insert_string (as1)

  -- Insert the second string.
  if as2 then
    goto_point (m1.pt)
    insert_string (as2)
  end
  unchain_marker (m1)

  -- Restore mark.
  pop_mark ()
  deactivate_mark ()

  -- Move forward if necessary.
  if forward_func ~= next_line then
    forward_func ()
  end

  return true
end

local function transpose (uniarg, forward_func, backward_func)
  local ret = true

  if warn_if_readonly_buffer () then
    return leNIL
  end

  if uniarg < 0 then
    local tmp_func = forward_func
    forward_func = backward_func
    backward_func = tmp_func
    uniarg = -uniarg
  end
  undo_save (UNDO_START_SEQUENCE, cur_bp.pt, 0, 0)
  for uni = 1, uniarg do
    ret = transpose_subr (forward_func, backward_func)
    if not ret then
      break
    end
  end
  undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)

  return bool_to_lisp (ret)
end

Defun ("transpose-chars",
       {"number"},
[[
Interchange characters around point, moving forward one character.
With prefix arg ARG, effect is to take character before point
and drag it forward past ARG other characters (backward if ARG negative).
If no argument and at end of line, the previous two chars are exchanged.
]],
  true,
  function (n)
    return transpose (n or 1, forward_char, backward_char)
  end
)

Defun ("transpose-words",
       {"number"},
[[
Interchange words around point, leaving point at end of them.
With prefix arg ARG, effect is to take word before or around point
and drag it forward past ARG other words (backward if ARG negative).
If ARG is zero, the words around or after point and around or after mark
are interchanged.
]],
  true,
  function (n)
    return transpose (n or 1, forward_word, backward_word)
  end
)

Defun ("transpose-sexps",
       {"number"},
[[
Like @kbd{M-x transpose-words} but applies to sexps.
]],
  true,
  function (n)
    return transpose (n or 1, forward_sexp, backward_sexp)
  end
)

Defun ("transpose-lines",
       {"number"},
[[
Exchange current line and previous line, leaving point after both.
With argument ARG, takes previous line and moves it past ARG lines.
With argument 0, interchanges line point is in with line mark is in.
]],
  true,
  function (n)
    return transpose (n or 1, next_line, previous_line)
  end
)
