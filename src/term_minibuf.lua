local overwrite_mode = false
local function do_minibuf_read (prompt, value, pos, cp, hp)
  local thistab
  local lasttab = -1
  local as = value
  local saved

  if pos == -1 then
    pos = #as
  end

  while true do
    local s
    if lasttab == COMPLETION_MATCHEDNONUNIQUE then
      s = " [Complete, but not unique]"
    elseif lasttab == COMPLETION_NOTMATCHED then
      s = " [No match]"
    elseif lasttab == COMPLETION_MATCHED then
      s = " [Sole completion]"
    else
      s = ""
    end

    draw_minibuf_read (prompt, as, s, pos)

    thistab = -1

    local c = getkey ()
    if c == KBD_NOKEY then
    elseif c == bit.bor (KBD_CTRL, string.byte ('z')) then
      CLUE_DO (L, "execute_function ('suspend_emacs')")
    elseif c == KBD_RET then
      term_move (term_height () - 1, 0)
      term_clrtoeol ()
      return as
    elseif c == KBD_CANCEL then
      term_move (term_height () - 1, 0)
      term_clrtoeol ()
      return
    elseif c == bit.bor (KBD_CTRL, string.byte ('a')) or c == KBD_HOME then
      pos = 0
    elseif c == bit.bor (KBD_CTRL, string.byte ('e')) or c == KBD_END then
      pos = #as
    elseif c == bit.bor (KBD_CTRL, string.byte ('b')) or c == KBD_LEFT then
      if pos > 0 then
        pos = pos - 1
      else
        ding ()
      end
    elseif c == bit.bor (KBD_CTRL, string.byte ('f')) or c == KBD_RIGHT then
      if pos < #as then
        pos = pos + 1
      else
        ding ()
      end
    elseif c == bit.bor (KBD_CTRL, string.byte ('k')) then
      -- FIXME: do kill-register save.
      if pos < #as then
        as = string.sub (as, pos + 1)
      else
        ding ()
      end
    elseif c == KBD_BS then
      if pos > 0 then
        as = string.sub (as, 1, pos - 1) .. string.sub (as, pos + 1)
        pos = pos - 1
      else
        ding ()
      end
    elseif c == bit.bor (KBD_CTRL, string.byte ('d')) or c == KBD_DEL then
      if pos < #as then
        as = string.sub (as, 1, pos) .. string.sub (as, pos + 2)
      else
        ding ()
      end
    elseif c == KBD_INS then
      overwrite_mode = not overwrite_mode
    elseif c == bit.bor (KBD_META, string.byte ('v')) or c == KBD_PGUP then
      if cp == nil then
        ding ()
      end
      if cp.poppedup then
        completion_scroll_down ()
        thistab = lasttab
      end
    elseif c == bit.bor (KBD_CTRL, string.byte ('v')) or c == KBD_PGDN then
      if cp == nil then
        ding ()
      end
      if cp.poppedup then
        completion_scroll_up ()
        thistab = lasttab
      end
    elseif c == KBD_UP or c == bit.bor (KBD_META, string.byte ('p')) then
      if hp then
        local elem = previous_history_element (hp)
        if elem then
          if not saved then
            saved = as
          end
          as = elem
        end
      end
    elseif c == KBD_DOWN or c == bit.bor (KBD_META, string.byte ('n')) then
      if hp then
        local elem = next_history_element (hp)
        if elem then
          as = elem
        elseif saved then
          as = saved
          saved = nil
        end
      end
    elseif c == KBD_TAB or (c == ' ' and cp) then
      if not cp then
        ding ()
      else
        if lasttab ~= -1 and lasttab ~= COMPLETION_NOTMATCHED and cp.poppedup then
          completion_scroll_up ()
          thistab = lasttab
        else
          thistab = completion_try (cp, as)
          if thistab == COMPLETION_NONUNIQUE or thistab == COMPLETION_MATCHEDNONUNIQUE then
            popup_completion (cp)
          end
          if thistab == COMPLETION_NONUNIQUE or thistab == COMPLETION_MATCHEDNONUNIQUE or thistab == COMPLETION_MATCHED then
            local bs = ""
            if cp.filename then
              bs = bs .. cp.path .. string.sub (cp.match, 1, cp.matchsize)
              if string.sub (as, 1, #bs) ~= bs then
                thistab = -1
              end
              as = bs
              pos = #as
            end
          elseif thistab == COMPLETION_NOTMATCHED then
            ding ()
          end
        end
      end
    else
      if c > 255 or not isprint (string.char (c)) then
        ding ()
      else
        as = string.sub (as, 1, pos) .. string.char (c) .. string.sub (as, pos + 1)
        pos = pos + 1
        if overwrite_mode and pos ~= #as then
          as = string.sub (as, 1, pos) .. string.sub (as, pos + 2)
        end
      end
    end

    lasttab = thistab
  end
end

function term_minibuf_write (s)
  term_move (term_height () - 1, 0)
  term_clrtoeol ()

  for i = 1, math.min (#s, term_width ()) do
    term_addch (string.byte (s, i))
  end
end

local function draw_minibuf_read (prompt, value, match, pointo)
  term_minibuf_write (prompt)

  local w, h = term_width (), term_height ()
  local margin = 1
  local n = 0

  if #prompt + pointo + 1 >= w then
    margin = margin + 1
    term_addch (string.byte ("$"))
    n = pointo - pointo % (w - #prompt - 2)
  end

  term_addstr (string.sub (value, n + 1, math.min (w - #prompt - margin, #value - n)))
  term_addstr (match)

  if #value - n >= w - #prompt - margin then
    term_move (h - 1, w - 1)
    term_addch (string.byte ("$"))
  end

  term_move (h - 1, #prompt + margin - 1 + pointo % (w - #prompt - margin))

  term_refresh ()
end

function term_minibuf_read (prompt, value, pos, cp, hp)
  if hp then
    history_prepare (hp)
  end

  local s = do_minibuf_read (prompt, value, pos, cp, hp)

  local old_wp = cur_wp
  local wp = find_window ("*Completions*")
  if cp and cp.popped_up and wp then
    set_current_window (wp)
    if cp.close then
      execute_function ("delete-window")
    elseif cp.old_bp then
      switch_to_buffer (cp.old_bp)
    end
    set_current_window (old_wp)
  end

  return s
end
