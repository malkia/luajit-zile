function term_minibuf_write (s)
  term_move (term_height () - 1, 0)
  term_clrtoeol ()

  for i = 1, math.min (#s, term_width ()) do
    term_addch (string.byte (s, i))
  end
end

-- FIXME: local
function draw_minibuf_read (prompt, value, match, pointo)
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
