(describe-function 'forward-char)
(other-window 1)
(set-mark (point))
(forward-line)
(copy-region-as-kill (mark) (point))
(other-window -1)
(yank)
(save-buffer)
(save-buffers-kill-emacs)
