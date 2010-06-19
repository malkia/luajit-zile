-- FIXME: local
minibuf_contents = nil


-- Minibuffer wrapper functions.

function minibuf_refresh ()
  if cur_wp then
    if minibuf_contents then
      term_minibuf_write (minibuf_contents)
    end

    -- Redisplay (and leave the cursor in the correct position).
    term_redisplay ()
    term_refresh ()
  end
end

-- Clear the minibuffer.
function minibuf_clear ()
  term_minibuf_write ("")
end

-- Write the specified string in the minibuffer.
function minibuf_write (s)
  minibuf_contents = s
  minibuf_refresh ()
end

function minibuf_test_in_completions (ms, cp)
  for i, v in pairs (cp.completions) do
    if v == s then
      return true
    end
  end
  return false
end
