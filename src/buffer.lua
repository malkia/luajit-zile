-- Copy a region of text into a string.
function copy_text_block (pt, size)
  local lp = pt.p
  local s = string.sub (lp.text, pt.o) .. "\n"

  lp = lp.next
  while #s < size do
    s = s .. lp.text .. "\n"
    lp = lp.next
  end

  return string.sub (s, 1, size)
end
