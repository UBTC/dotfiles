(require 'cofi-util)
(add-to-loadpath "~/.elisp/vendor/evil/"
                 "~/.elisp/vendor/evil-surround/"
                 "~/.elisp/vendor/evil-leader/")
(require 'undo-tree)
(require 'evil-numbers)
(setq evil-find-skip-newlines t)
(setq evil-move-cursor-back nil
      evil-cross-lines t)
(setq evil-default-cursor #'cofi/evil-cursor)
(setq evil-mode-line-format nil)
(setq evil-leader/leader ","
      evil-leader/in-all-states t)
(require 'evil-leader)
(require 'evil)

;;; evil-surround
(require-and-exec 'surround
  (global-surround-mode 1)
  (add-to-hooks (lambda ()
                  (make-local-variable 'surround-pairs-alist)
                  (push '(?` . ("`" . "'")) surround-pairs-alist))
                '(emacs-lisp-mode-hook lisp-mode-hook))
  (add-to-hooks (lambda ()
                  (make-local-variable 'surround-pairs-alist)
                  (push '(?~ . ("``" . "``")) surround-pairs-alist))
                '(markdown-mode-hook rst-mode-hook)))

(evil-set-toggle-key "<pause>")
(evil-mode 1)

(evil-define-command cofi/evil-maybe-exit ()
  :repeat change
  (interactive)
  (let ((modified (buffer-modified-p))
        (entry-key ?j)
        (exit-key ?k))
    (insert entry-key)
    (let ((evt (read-event (format "Insert %c to exit insert state" exit-key) nil 0.5)))
      (cond
       ((null evt) (message ""))
       ((and (integerp evt) (char-equal evt exit-key))
          (delete-char -1)
          (set-buffer-modified-p modified)
          (push 'escape unread-command-events))
       (t (push evt unread-command-events))))))

(loop for (mode . state) in '((inferior-emacs-lisp-mode . emacs)
                              (pylookup-mode            . emacs)
                              (comint-mode              . emacs)
                              (shell-mode               . emacs)
                              (term-mode                . emacs))
      do (evil-set-initial-state mode state))

(fill-keymap evil-normal-state-map
             "Y"     (cmd (evil-yank-characters (point) (point-at-eol)))
             "+"     'evil-numbers/inc-at-pt
             "-"     'evil-numbers/dec-at-pt
             "SPC"   'ace-jump-char-mode
             "S-SPC" 'ace-jump-word-mode
             "C-SPC" 'ace-jump-line-mode
             "go"    'goto-char
             "C-t"   'transpose-chars
             "C-:"   'eval-expression
             ":"     'evil-repeat-find-char-reverse)

(fill-keymap evil-motion-state-map
             "_"     'evil-first-non-blank
             "C-e"   'end-of-line
             "C-S-d" 'evil-scroll-up
             "C-S-f" 'evil-scroll-page-up
             "_"     'evil-first-non-blank
             "C-y"   nil)

(fill-keymap evil-insert-state-map
             "j"   'cofi/evil-maybe-exit
             "C-h" 'backward-delete-char
             "C-y" 'yank
             "C-e" 'end-of-line)

(require-and-exec 'sackspace
  (sack/install-in-evil))

(evil-declare-key 'normal org-mode-map
  (kbd "RET") 'org-open-at-point
  "za"        'org-cycle
  "zA"        'org-shifttab
  "zm"        'hide-body
  "zr"        'show-all
  "zo"        'show-subtree
  "zO"        'show-all
  "zc"        'hide-subtree
  "zC"        'hide-all
  (kbd "M-j") 'org-shiftleft
  (kbd "M-k") 'org-shiftright
  (kbd "M-H") 'org-metaleft
  (kbd "M-J") 'org-metadown
  (kbd "M-K") 'org-metaup
  (kbd "M-L") 'org-metaright)

(evil-declare-key 'insert org-mode-map
  (kbd "M-j") 'org-shiftleft
  (kbd "M-k") 'org-shiftright
  (kbd "M-H") 'org-metaleft
  (kbd "M-J") 'org-metadown
  (kbd "M-K") 'org-metaup
  (kbd "M-L") 'org-metaright)

(defadvice evil-goto-definition (around evil-clever-goto-def activate)
  "Make use of emacs', slime's and etags possibilities for finding definitions."
  (case major-mode
    (lisp-mode (if slime-mode
                   (or (slime-find-definitions (symbol-name (symbol-at-point)))
                       ad-do-it)
                 ad-do-it))
    (emacs-lisp-mode (condition-case nil
                         (find-function (symbol-at-point))
                       (error (condition-case nil
                                  (find-variable (symbol-at-point))
                                (error ad-do-it)))))
    (otherwise
     (let ((tag (symbol-name (symbol-at-point))))
       (if (find-tag-noselect tag)
           (find-tag tag)
         ad-do-it)))))

(defun cofi/clear-empty-lines ()
  (let ((line (buffer-substring (point-at-bol) (point-at-eol))))
    (when (string-match "^\\( +\\)$" line)
      (delete-region (point-at-bol) (point-at-eol)))))
(add-hook 'evil-insert-state-exit-hook #'cofi/clear-empty-lines)

(evil-leader/set-key
  "e" 'cofi/file
  "E" 'cofi/file-alternate
  "o" 'cofi-find-at-alias
  "O" 'cofi-find-anything-at-alias
  "b" 'cofi/buffer
  "B" 'cofi/buffer-alternate
  "w" 'save-buffer
  "W" 'save-some-buffers
  "k" 'kill-buffer-and-window
  "K" 'kill-this-buffer
  "<" 'cofi-cd-alias
  "d" 'dired-jump
  "D" 'cofi-dired-alias

  "m" 'compile

  "n" 'split-window-horizontally
  "c" 'delete-window
  "N" 'make-frame-command
  "C" 'delete-frame

  "g" 'magit-status
  "h" 'monky-status

  "s" 'cofi/switch-file
  ";" 'cofi/end-prog-line

  "." 'evil-ex-read-command)

(defun cofi/evil-cursor ()
  "Change cursor color according to evil-state."
  (let ((default "OliveDrab4")
        (cursor-colors '((insert . "dark orange")
                         (emacs  . "sienna")
                         (visual . "white"))))
    (setq cursor-type (if (eq evil-state 'visual)
                          'hollow
                        'bar))
    (set-cursor-color (def-assoc evil-state cursor-colors default))))

(require 'cofi-windowing)
;; allow C-w to be shadowed in emacs-state -- `evil-want-C-w-in-emacs-state' doesn't allow this
(global-set-key (kbd "C-w") evil-window-map)
;; alternative if shadowed
(global-set-key (kbd "C-c w") evil-window-map)
;; Windowing
(fill-keymap evil-window-map
    ;; Splitting
    "\\" 'split-window-vertically
    "|" 'split-window-horizontally
    "/" 'smart-split

    ;; Deleting
    "d" 'delete-window
    "1" 'delete-other-windows

    ;; Sizing
    "RET" 'enlarge-window
    "-"   'shrink-window-horizontally
    "+"   'enlarge-window-horizontally

    ;; Moving
    "<left>"  'evil-window-left
    "<down>"  'evil-window-down
    "<up>"    'evil-window-up
    "<right>" 'evil-window-right

    ;; Swapping
    "M-h"       'swap-with-left
    "M-j"       'swap-with-down
    "M-k"       'swap-with-up
    "M-l"       'swap-with-right
    "S-<left>"  'swap-with-left
    "S-<down>"  'swap-with-down
    "S-<up>"    'swap-with-up
    "S-<right>" 'swap-with-right
    "SPC"       'swap-window

    ;; winner-mode
    "u" 'winner-undo
    "C-r" 'winner-reod
    ;; shadow rotating in evil-window-map
    "C-R" 'winner-redo)

(provide 'cofi-evil)
