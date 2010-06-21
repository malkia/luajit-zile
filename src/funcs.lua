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

Defun {"universal-argument",
[[
Begin a numeric argument for the following command.
Digits or minus sign following @kbd{C-u} make up the numeric argument.
@kbd{C-u} following the digits or minus sign ends the argument.
@kbd{C-u} without digits or minus sign provides 4 as argument.
Repeating @kbd{C-u} without digits or minus sign multiplies the argument
by 4 each time.
]],
  function (l)
    local i = 0
    local arg = 1
    local sgn = 1
    local key
    local as = ""

    -- Need to process key used to invoke universal-argument.
    pushkey (lastkey)

    thisflag = bit.bor (thisflag, FLAG_UNIARG_EMPTY)

    while true do
      as = as .. '-' -- Add the `-' character.
      local key = do_binding_completion (as)
      as = string.sub (as, 1, -2) -- Remove the `-' character.

      -- Cancelled.
      if key == KBD_CANCEL then
        ok = call_zile_command ("keyboard_quit")
        break
      -- Digit pressed.
      elseif isdigit (bit.band (key, 0xff)) then
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
      last_uniarg = arg * sgn
      thisflag = bit.bor (thisflag, FLAG_SET_UNIARG)
      minibuf_clear ()
    end
  end
}
