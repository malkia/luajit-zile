local kill_ring_text

function maybe_free_kill_ring ()
  if _last_command ~= "kill-region" then
    kill_ring_text = nil
  end
end

local function kill_ring_push (s)
  kill_ring_text = (kill_ring_text or "") .. s
end

local function copy_or_kill_region (kill, rp)
  maybe_free_kill_ring ()
  kill_ring_push (copy_text_block (rp.start, rp.size))

  if kill then
    if cur_bp.readonly then
      minibuf_error ("Read only text copied to kill ring")
    else
      assert (delete_region (rp))
    end
  end

  _this_command = "kill-region"
  deactivate_mark ()
end

local function copy_or_kill_the_region (kill)
  local rp = region_new ()

  if calculate_the_region (rp) then
    return copy_or_kill_region (kill, rp)
  end

  return false
end

local function kill_text (uniarg, mark_func)
  maybe_free_kill_ring ()

  if warn_if_readonly_buffer () then
    return leNIL
  end

  push_mark ()
  undo_save (UNDO_START_SEQUENCE, cur_bp.pt, 0, 0)
  execute_function (mark_func, uniarg, true)
  execute_function ("kill-region")
  undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)
  pop_mark ()

  _this_command = "kill-region"
  minibuf_write ("") -- Erase "Set mark" message.
  return leT
end

Defun ("kill-word",
       {"number"},
[[
Kill characters forward until encountering the end of a word.
With argument @i{arg}, do this that many times.
]],
  true,
  function (arg)
    return kill_text (arg, "mark-word")
  end
)

Defun ("backward-kill-word",
       {"number"},
[[
Kill characters backward until encountering the end of a word.
With argument @i{arg}, do this that many times.
]],
  true,
  function (arg)
    return kill_text (-arg, "mark-word")
  end
)

Defun ("kill-sexp",
       {"number"},
[[
Kill the sexp (balanced expression) following the cursor.
With @i{arg}, kill that many sexps after the cursor.
Negative arg -N means kill N sexps before the cursor.
]],
  true,
  function (arg)
    return kill_text (arg, "mark-sexp")
  end
)

Defun ("yank",
       {},
[[
Reinsert the last stretch of killed text.
More precisely, reinsert the stretch of killed text most recently
killed @i{or} yanked.  Put point at end, and set mark at beginning.
]],
  true,
  function ()
    if not kill_ring_text then
      minibuf_error ("Kill ring is empty")
      return leNIL
    end

    if warn_if_readonly_buffer () then
      return leNIL
    end

    set_mark_interactive ()

    undo_save (UNDO_REPLACE_BLOCK, cur_bp.pt, 0, #kill_ring_text)
    undo_nosave = true
    insert_string (kill_ring_text)
    undo_nosave = false

    deactivate_mark ()
  end
)

Defun ("kill-region",
       {},
[[
Kill between point and mark.
The text is deleted but saved in the kill ring.
The command @kbd{C-y} (yank) can retrieve it from there.
If the buffer is read-only, Zile will beep and refrain from deleting
the text, but put the text in the kill ring anyway.  This means that
you can use the killing commands to copy text from a read-only buffer.
If the previous command was also a kill command,
the text killed this time appends to the text killed last time
to make one entry in the kill ring.
]],
  true,
  function ()
    return bool_to_lisp (copy_or_kill_the_region (true))
  end
)

Defun ("copy-region-as-kill",
       {},
[[
Save the region as if killed, but don't kill it.
]],
  true,
  function ()
    return bool_to_lisp (copy_or_kill_the_region (false))
  end
)

local function kill_to_bol ()
  if not bolp () then
    local rp = region_new ()
    rp.size = cur_bp.pt.o
    cur_bp.pt.o = 0
    rp.start = cur_bp.pt

    return copy_or_kill_region (true, rp)
  end

  return true
end

local function kill_line (whole_line)
  local ok = true
  local only_blanks_to_end_of_line = true

  if not whole_line then
    for i = cur_bp.pt.o, #cur_bp.pt.p.text do
      local c = cur_bp.pt.p.text[i]
      if not (c == ' ' or c == '\t') then
        only_blanks_to_end_of_line = false
        break
      end
    end
  end

  if eobp () then
    minibuf_error ("End of buffer")
    return false
  end

  undo_save (UNDO_START_SEQUENCE, cur_bp.pt, 0, 0)

  if not eolp () then
    local rp = region_new ()

    rp.start = cur_bp.pt
    rp.size = #cur_bp.pt.p.text - cur_bp.pt.o

    ok = copy_or_kill_region (true, rp)
  end

  if ok and (whole_line or only_blanks_to_end_of_line) and not eobp () then
    if not execute_function ("delete-char") then
      return false
    end

    kill_ring_push ("\n")
    _this_command = "kill-region"
  end

  undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)

  return ok
end

local function kill_whole_line ()
  return kill_line (true)
end

local function kill_line_backward ()
  return previous_line () and kill_whole_line ()
end

Defun ("kill-line",
       {"number"},
[[
Kill the rest of the current line; if no nonblanks there, kill thru newline.
With prefix argument @i{arg}, kill that many lines from point.
Negative arguments kill lines backward.
With zero argument, kills the text before point on the current line.

If @samp{kill-whole-line} is non-nil, then this command kills the whole line
including its terminating newline, when used at the beginning of a line
with no argument.
]],
  true,
  function (arg)
    local ok = leT

    maybe_free_kill_ring ()

    if not arg then
      ok = bool_to_lisp (kill_line (bolp () and get_variable_bool ("kill-whole-line")))
    else
      undo_save (UNDO_START_SEQUENCE, cur_bp.pt, 0, 0)
      if arg <= 0 then
        ok = bool_to_lisp (kill_to_bol ())
      end
      if arg ~= 0 and ok == leT then
        ok = execute_with_uniarg (true, arg, kill_whole_line, kill_line_backward)
      end
      undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)
    end

    deactivate_mark ()
  end
)
