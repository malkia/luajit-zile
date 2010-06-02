-- FIXME: local
minibuf_contents = nil


-- Minibuffer wrapper functions.

function minibuf_refresh ()
  if cur_wp then
    term_minibuf_write (minibuf_contents)

    -- Redisplay (and leave the cursor in the correct position).
    term_redisplay ()
    term_refresh ()
  end
end
