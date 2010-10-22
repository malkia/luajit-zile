Defun ("beginning-of-line",
       {},
[[
Move point to beginning of current line.
]],
  true,
  function ()
    cur_bp.pt = line_beginning_position (get_variable_number ("current-prefix-arg"))
    cur_bp.goalc = 0
  end
)

Defun ("end-of-line",
       {},
[[
Move point to end of current line.
]],
  true,
  function ()
    cur_bp.pt = line_end_position (get_variable_number ("current-prefix-arg"))
    cur_bp.goalc = 1e100 -- FIXME: Use a constant
  end
)

local function move_char (dir)
  if (dir > 0 and not eolp ()) or (dir < 0 and not bolp ()) then
    cur_bp.pt.o = cur_bp.pt.o + dir
    return true
  elseif (dir > 0 and not eobp ()) or (dir < 0 and not bobp ()) then
    thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)
    if dir > 0 then
      cur_bp.pt.p = cur_bp.pt.p.next
    else
      cur_bp.pt.p = cur_bp.pt.p.prev
    end
    cur_bp.pt.n = cur_bp.pt.n + dir
    if dir > 0 then
      execute_function ("beginning-of-line")
    else
      execute_function ("end-of-line")
    end
    return true
  end

  return false
end

function backward_char ()
  return move_char (-1)
end

function forward_char ()
  return move_char (1)
end

Defun ("backward-char",
       {"number"},
[[
Move point left N characters (right if N is negative).
On attempt to pass beginning or end of buffer, stop and signal error.
]],
  true,
  function (n)
    local ok = execute_with_uniarg (false, n, backward_char, forward_char)
    if ok == leNIL then
      minibuf_error ("Beginning of buffer")
    end
    return ok
  end
)

Defun ("forward-char",
       {"number"},
[[
Move point right N characters (left if N is negative).
On reaching end of buffer, stop and signal error.
]],
  true,
  function (n)
    local ok = execute_with_uniarg (false, n, forward_char, backward_char)
    if ok == leNIL then
      minibuf_error ("End of buffer")
    end
    return ok
  end
)

-- Get the goal column, expanding tabs.
function get_goalc_bp (bp, pt)
  local col = 0
  local t = tab_width (bp)

  for i = 1, math.min (pt.o, #pt.p.text) do
    if string.sub (pt.p.text, i, 1) == '\t' then
      col = bit.bor (col, t - 1)
    end
    col = col + 1
  end

  return col
end

function get_goalc ()
  return get_goalc_bp (cur_bp, cur_bp.pt)
end

-- Go to the column `goalc'.  Take care of expanding tabulations.
local function goto_goalc ()
  local col = 0

  local i = 1
  while i <= #cur_bp.pt.p.text do
    if col == cur_bp.goalc then
      break
    elseif cur_bp.pt.p.text[i] == '\t' then
      local t = tab_width (cur_bp)
      for w = t - col % t, 1, -1 do
        col = col + 1
        if col == cur_bp.goalc then
          break
        end
      end
    else
      col = col + 1
    end
    i = i + 1
  end

  cur_bp.pt.o = i - 1
end

local function move_line (n)
  local ok = true
  local dir

  if n == 0 then
    return false
  elseif n > 0 then
    dir = 1
    if n > cur_bp.last_line - cur_bp.pt.n then
      ok = false
      n = cur_bp.last_line - cur_bp.pt.n
    end
  else
    dir = -1
    n = -n
    if n > cur_bp.pt.n then
      ok = false
      n = cur_bp.pt.n
    end
  end

  for i = n, 1, -1 do
    cur_bp.pt.p = cur_bp.pt.p[dir > 0 and "next" or "prev"]
    cur_bp.pt.n = cur_bp.pt.n + dir
  end

  if _last_command ~= "next-line" and _last_command ~= "previous-line" then
    cur_bp.goalc = get_goalc ()
  end
  goto_goalc ()

  thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)

  return ok
end

Defun ("goto-char",
       {"number"},
[[
Read a number N and move the cursor to character number N.
Position 1 is the beginning of the buffer.
]],
  true,
  function (n)
    local ok = leT

    if not n then
      repeat
        local ms = minibuf_read ("Goto char: ", "")
        if not ms then
          ok = execute_function ("keyboard-quit")
          break
        end
        n = tonumber (ms, 10);
        if not n then
          ding ()
        end
      until n
    end

    if ok == leT and n then
      gotobob ()
      for _ = 1, n - 1 do
        if not forward_char () then
          break
        end
      end
    end
  end
)

Defun ("goto-line",
       {"number"},
[[
Goto line arg, counting from line 1 at beginning of buffer.
]],
  true,
  function (n)
    n = n or get_variable_number ("current-prefix-arg")
    if not n and interactive then
      n = minibuf_read_number ("Goto line: ")
      if n == "" then
        -- FIXME: This error message should come from deeper down.
        minibuf_error ("End of file during parsing")
      end
    end

    if type (n) == "number" then
      move_line ((math.max (n, 1) - 1) - cur_bp.pt.n)
      execute_function ("beginning-of-line")
    end
  end
)

function previous_line ()
  return move_line (-1)
end

function next_line ()
  return move_line (1)
end

Defun ("previous-line",
       {"number"},
[[
Move cursor vertically up one line.
If there is no character in the target line exactly over the current column,
the cursor is positioned after the character in that line which spans this
column, or at the end of the line if it is not long enough.
]],
  true,
  function (n)
    local ok = leT
    n = n or get_variable_number ("current-prefix-arg")
    if n < 0 or not bobp () then
      ok = execute_with_uniarg (false, n, previous_line, next_line)
    end
    if ok == leNIL then
      execute_function ("beginning-of-line")
    end
  end
)

Defun ("next-line",
       {"number"},
[[
Move cursor vertically down one line.
If there is no character in the target line exactly under the current column,
the cursor is positioned after the character in that line which spans this
column, or at the end of the line if it is not long enough.
]],
  true,
  function (n)
    local ok = leT
    n = n or get_variable_number ("current-prefix-arg")
    if n < 0 or not eobp () then
      ok = execute_with_uniarg (false, n, next_line, previous_line)
    end
    if ok == leNIL then
      execute_function ("end-of-line")
    end
  end
)

-- Move point to the beginning of the buffer; do not touch the mark.
function gotobob ()
  cur_bp.pt = point_min ()
  thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)
end

Defun ("beginning-of-buffer",
       {},
[[
Move point to the beginning of the buffer; leave mark at previous position.
]],
  true,
  function ()
    set_mark_interactive ()
    gotobob ()
  end
)

-- Move point to the end of the buffer; do not touch the mark.
function gotoeob ()
  cur_bp.pt = point_max ()
  thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)
end

Defun ("end-of-buffer",
       {},
[[
Move point to the end of the buffer; leave mark at previous position.
]],
  true,
  function ()
    set_mark_interactive ()
    gotoeob ()
  end
)

local function scroll_down ()
  if not window_top_visible (cur_wp) then
    return move_line (-get_window_eheight (cur_wp))
  end

  minibuf_error ("Beginning of buffer")
  return false
end

local function scroll_up ()
  if not window_bottom_visible (cur_wp) then
    return move_line (get_window_eheight (cur_wp))
  end

  minibuf_error ("End of buffer")
  return false
end

Defun ("scroll-down",
       {"number"},
[[
Scroll text of current window downward near full screen.
]],
  true,
  function (n)
    return execute_with_uniarg (false, n or 1, scroll_down, scroll_up)
  end
)

Defun ("scroll-up",
       {"number"},
[[
Scroll text of current window upward near full screen.
]],
  true,
  function (n)
    return execute_with_uniarg (false, n or 1, scroll_up, scroll_down)
  end
)
