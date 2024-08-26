;;; apparmor-mode.el --- Major mode for editing AppArmor policy files         -*- lexical-binding: t; -*-

;; Copyright (c) 2018 Canonical Ltd.

;; Author: Alex Murray <alex.murray@canonical.com>
;; Maintainer: Alex Murray <alex.murray@canonical.com>
;; URL: https://github.com/alexmurray/apparmor-mode
;; Version: 0.8.2
;; Package-Requires: ((emacs "26.1"))

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; The following documentation sources were used:
;; https://gitlab.com/apparmor/apparmor/wikis/QuickProfileLanguage
;; https://gitlab.com/apparmor/apparmor/wikis/ProfileLanguage

;; TODO:
;; - do smarter completion syntactically via regexps
;; - decide if to use entire line regexp for statements or
;;   - not (ie just a subset?)  if we use regexps above then
;;   - should probably keep full regexps here so can reuse
;; - expand highlighting of mount rules (options=...) similar to dbus
;; - add tests via ert etc

;;;; Setup

;; (require 'apparmor-mode)

;;; Code:

;; for flycheck integration
(declare-function flycheck-define-command-checker "ext:flycheck.el"
                  (symbol docstring &rest properties))
(declare-function flycheck-valid-checker-p "ext:flycheck.el")
(defvar flycheck-checkers)

(defgroup apparmor nil
  "Major mode for editing AppArmor policies."
  :group 'tools)

(defcustom apparmor-mode-indent-offset 2
  "Indentation offset in `apparmor-mode' buffers."
  :type 'integer
  :group 'apparmor)

(defvar apparmor-mode-keywords '("all" "audit" "capability" "chmod" "delegate"
                                 "dbus" "deny" "file" "flags" "io_uring" "include"
                                 "include if exists" "link" "mount" "mqueue"
                                 "network" "on" "owner" "pivot_root" "profile"
                                 "quiet" "remount" "rlimit" "safe" "subset" "to"
                                 "umount" "unsafe" "userns"))

(defvar apparmor-mode-profile-flags '("enforce" "complain" "debug" "kill"
                                      "chroot_relative" "namespace_relative"
                                      "attach_disconnected" "no_attach_disconnected"
                                      "chroot_attach" "chroot_no_attach"
                                      "unconfined"))

(defvar apparmor-mode-capabilities '("audit_control" "audit_write" "chown"
                                     "dac_override" "dac_read_search" "fowner"
                                     "fsetid" "ipc_lock" "ipc_owner" "kill"
                                     "lease" "linux_immutable" "mac_admin"
                                     "mac_override" "mknod" "net_admin"
                                     "net_bind_service" "net_broadcast"
                                     "net_raw" "setfcap" "setgid" "setpcap"
                                     "setuid" "syslog" "sys_admin" "sys_boot"
                                     "sys_chroot" "sys_module" "sys_nice"
                                     "sys_pacct" "sys_ptrace" "sys_rawio"
                                     "sys_resource" "sys_time"
                                     "sys_tty_config"))

(defvar apparmor-mode-network-permissions '("create" "accept" "bind" "connect"
                                            "listen" "read" "write" "send"
                                            "receive" "getsockname" "getpeername"
                                            "getsockopt" "setsockopt" "fcntl"
                                            "ioctl" "shutdown" "getpeersec"
                                            "sqpoll" "override_creds"))

(defvar apparmor-mode-network-domains '("inet" "ax25" "ipx" "appletalk" "netrom"
                                        "bridge" "atmpvc" "x25" "inet6" "rose"
                                        "netbeui" "security" "key" "packet"
                                        "ash" "econet" "atmsvc" "sna" "irda"
                                        "pppox" "wanpipe" "bluetooth" "unix"))

(defvar apparmor-mode-network-types '("stream" "dgram" "seqpacket" "raw" "rdm"
                                      "packet" "dccp"))

;; TODO: this is not complete since is not fully documented
(defvar apparmor-mode-network-protocols '("tcp" "udp" "icmp"))

(defvar apparmor-mode-dbus-permissions '("r" "w" "rw" "send" "receive"
                                         "acquire" "bind" "read" "write"))

(defvar apparmor-mode-rlimit-types '("fsize" "data" "stack" "core" "rss" "as"
                                     "memlock" "msgqueue" "nofile" "locks"
                                     "sigpending" "nproc" "rtprio" "cpu"
                                     "nice"))

(defvar apparmor-mode-abi-regexp "^\\s-*\\(#?abi\\)\\s-+\\([<\"][[:graph:]]+[\">]\\)")

(defvar apparmor-mode-include-regexp "^\\s-*\\(#?include\\( if exists\\)?\\)\\s-+\\([<\"][[:graph:]]+[\">]\\)")

(defvar apparmor-mode-capability-regexp (concat  "^\\s-*\\(capability\\)\\s-+\\("
                                                 (regexp-opt apparmor-mode-capabilities)
                                                 "\\s-*\\)*"))

(defvar apparmor-mode-variable-name-regexp "@{[[:alpha:]_]+}")

(defvar apparmor-mode-variable-regexp
  (concat "^\\s-*\\(" apparmor-mode-variable-name-regexp "\\)\\s-*\\(\\+?=\\)\\s-*\\([[:graph:]]+\\)\\(\\s-+\\([[:graph:]]+\\)\\)?\\s-*\\(#.*\\)?$"))

(defvar apparmor-mode-profile-name-regexp "[[:alnum:]]+")

(defvar apparmor-mode-profile-attachment-regexp "[][[:alnum:]*@/_{},-.?]+")

(defvar apparmor-mode-profile-flags-regexp
  (concat  "\\(flags\\)=(\\(" (regexp-opt apparmor-mode-profile-flags) "\\s-*\\)*)") )

(defvar apparmor-mode-profile-regexp
  (concat "^\\s-*\\(\\(profile\\)\\s-+\\(\\(" apparmor-mode-profile-name-regexp "\\)\\s-+\\)?\\)?\\(\\^?" apparmor-mode-profile-attachment-regexp "\\)\\(\\s-+" apparmor-mode-profile-flags-regexp "\\)?\\s-+{\\s-*$"))

(defvar apparmor-mode-file-rule-permissions-regexp "[CPUaciklmpruwx]+")

(defvar apparmor-mode-file-rule-permissions-prefix-regexp
  (concat "^\\s-*\\(\\(audit\\|owner\\|deny\\)\\s-+\\)*\\(file\\s-+\\)?"
          "\\(" apparmor-mode-file-rule-permissions-regexp "\\)\\s-+"
          "\\(" apparmor-mode-profile-attachment-regexp "\\)\\s-*"
          "\\(->\\s-+\\(" apparmor-mode-profile-attachment-regexp "\\)\\)?\\s-*"
          ","))

(defvar apparmor-mode-file-rule-permissions-suffix-regexp
  (concat "^\\s-*\\(\\(audit\\|owner\\|deny\\)\\s-+\\)*\\(file\\s-+\\)?"
          "\\(" apparmor-mode-profile-attachment-regexp "\\)\\s-+"
          "\\(" apparmor-mode-file-rule-permissions-regexp "\\)\\s-*"
          "\\(->\\s-+\\(" apparmor-mode-profile-attachment-regexp "\\)\\)?\\s-*"
          ","))

(defvar apparmor-mode-network-rule-regexp
  (concat
   "^\\s-*\\(\\(audit\\|quiet\\|deny\\)\\s-+\\)*network\\s-*"
   "\\(" (regexp-opt apparmor-mode-network-permissions 'words) "\\)?\\s-*"
   "\\(" (regexp-opt apparmor-mode-network-domains 'words) "\\)?\\s-*"
   "\\(" (regexp-opt apparmor-mode-network-types 'words) "\\)?\\s-*"
   "\\(" (regexp-opt apparmor-mode-network-protocols 'words) "\\)?\\s-*"
   ;; TODO: address expression
   "\\(delegate to\\s-+\\(" apparmor-mode-profile-attachment-regexp "\\)\\)?\\s-*"
   ","))

(defvar apparmor-mode-dbus-rule-regexp
  (concat
   "^\\s-*\\(\\(audit\\|deny\\)\\s-+\\)?dbus\\s-*"
   "\\(\\(bus\\)=\\(system\\|session\\)\\)?\\s-*"
   "\\(\\(dest\\)=\\([[:alpha:].]+\\)\\)?\\s-*"
   "\\(\\(path\\)=\\([[:alpha:]/]+\\)\\)?\\s-*"
   "\\(\\(interface\\)=\\([[:alpha:].]+\\)\\)?\\s-*"
   "\\(\\(method\\)=\\([[:alpha:]_]+\\)\\)?\\s-*"
   ;; permissions - either a single permission or multiple permissions in
   ;; parentheses with commas and whitespace separating
   "\\("
   (regexp-opt apparmor-mode-dbus-permissions 'words)
   "\\|"
   "("
   (regexp-opt apparmor-mode-dbus-permissions 'words)
   "\\("
   (regexp-opt apparmor-mode-dbus-permissions 'words) ",\\s-+"
   "\\)"
   "\\)?\\s-*"
   ","))

(defvar apparmor-mode-font-lock-defaults
  `(((,(regexp-opt apparmor-mode-keywords 'symbols) . font-lock-keyword-face)
     (,(regexp-opt apparmor-mode-rlimit-types 'symbols) . font-lock-type-face)
     ;; comma at end-of-line
     (",\\s-*$" . 'font-lock-builtin-face)
     ;; TODO be more specific about where these are valid
     ("->" . 'font-lock-builtin-face)
     ("[=\\+()]" . 'font-lock-builtin-face)
     ("+=" . 'font-lock-builtin-face)
     ("<=" . 'font-lock-builtin-face) ; rlimit
     ;; abi
     (,apparmor-mode-abi-regexp
      (1 font-lock-preprocessor-face t)
      (2 font-lock-string-face t))
     ;; includes
     (,apparmor-mode-include-regexp
      (1 font-lock-preprocessor-face t)
      (3 font-lock-string-face t))
     ;; variables
     (,apparmor-mode-variable-name-regexp 0 font-lock-variable-name-face t)
     ;; profiles
     (,apparmor-mode-profile-regexp
      (4 font-lock-function-name-face t nil)
      (5 font-lock-variable-name-face t))
     ;; capabilities
     (,apparmor-mode-capability-regexp 2 font-lock-type-face t)
     ;; file rules
     (,apparmor-mode-file-rule-permissions-prefix-regexp
      (3 font-lock-keyword-face nil t) ; class
      (4 font-lock-constant-face t) ; permissions
      (7 font-lock-function-name-face nil t)) ;profile
     (,apparmor-mode-file-rule-permissions-suffix-regexp
      (3 font-lock-keyword-face nil t) ; class
      (5 font-lock-constant-face t) ; permissions
      (7 font-lock-function-name-face nil t)) ;profile
     ;; network rules
     (,apparmor-mode-network-rule-regexp
      (3 font-lock-constant-face t) ;permissions
      (4 font-lock-function-name-face t) ;domain
      (5 font-lock-variable-name-face t) ;type
      (6 font-lock-type-face t)) ; protocol
     ;; dbus rules
     (,apparmor-mode-dbus-rule-regexp
      (4 font-lock-variable-name-face t) ;bus
      (5 font-lock-constant-face t) ;system/session
      (7 font-lock-variable-name-face t) ;dest
      (10 font-lock-variable-name-face t)
      (13 font-lock-variable-name-face t)
      (16 font-lock-variable-name-face t)))))

(defvar apparmor-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; # is comment start
    (modify-syntax-entry ?# "<" table)
    ;; newline finishes comment line
    (modify-syntax-entry ?\n ">" table)
    table))

(defun apparmor-mode-complete-include (prefix &optional local)
  "Return list of completions of include for PREFIX which could be LOCAL."
  (let* ((file-name (file-name-base prefix))
         (parent (file-name-directory prefix))
         (directory (concat (if local default-directory "/etc/apparmor.d") "/"
                            parent)))
    ;; need to prepend all of directory part of prefix
    (mapcar (lambda (f) (concat parent f))
            (file-name-all-completions file-name directory))))

;; TODO - make a lot smarter than just keywords - complete paths from the
;; system if we look like a path, do sub-completion based on the current lines
;; keyword etc - ie match against syntax highlighting regexes and use those to
;; further complete etc
(defun apparmor-mode-completion-at-point ()
  "`completion-at-point' function for `apparmor-mode'."
  (let ((prefix (or (thing-at-point 'word t) ""))
        (bounds (bounds-of-thing-at-point 'word))
        (bol (save-excursion (beginning-of-line) (point)))
        (candidates nil))
    (setq candidates
          (cond ((looking-back "#?include\\s-+\\([<\"]\\)[[:graph:]]*" bol)
                 (apparmor-mode-complete-include
                  prefix (string= (match-string 1) "\"")))
                (t apparmor-mode-keywords)))
    (list (car bounds) ; start
          (cdr bounds) ; end
          candidates
          :company-docsig #'identity)))

(defun apparmor-mode-indent-line ()
  "Indent current line in `apparmor-mode'."
  (interactive)
  (if (bolp)
      (apparmor-mode--indent-line)
    (save-excursion
      (apparmor-mode--indent-line))))

(defun apparmor-mode--find-first-previous-non-blank-line ()
  "Find the first non-blank line before the current line."
  (forward-line -1)
  (beginning-of-line)
  (while (and (not (bobp))
              (looking-at "^\\s-*\\(#.*\\)?$"))
    (forward-line -1)
    (beginning-of-line)))

(defun apparmor-mode--block-depth ()
  "Count the number of blocks before the current line."
  (save-excursion
    (let ((depth 0))
      ;; call backward-up-list and count each time until we hit an error
      (condition-case nil
          (while (progn (backward-up-list) t)
            (setq depth (1+ depth)))
        (error depth))
      depth)))

(defun apparmor-mode--indent-line ()
  "Indent current line in `apparmor-mode'."
  (beginning-of-line)
  (cond
   ((bobp)
    ;; simple case indent to 0
    (indent-line-to 0))
   ((looking-at "^\\s-*}\\s-*$")
    ;; if closing a block then indent relative to block depth minus one since
    ;; this is closing the block
    (indent-line-to (* (1- (apparmor-mode--block-depth)) apparmor-mode-indent-offset)))
   ;; if opening a block then indent relative to block depth
   ((looking-at "^.*{[^}]*\\s-*$")
    (indent-line-to (* (apparmor-mode--block-depth) apparmor-mode-indent-offset)))
   ;; other cases need to look at previous lines
   (t
    (indent-line-to (save-excursion
                      (let ((orig (point)))
                        (apparmor-mode--find-first-previous-non-blank-line)
                        (cond
                         ((bobp)
                          0)
                         ((looking-at "\\(^.*{[^}]*$\\)")
                          ;; previous line opened a block, indent to that line
                          (+ (current-indentation) apparmor-mode-indent-offset))
                         ((looking-at "\\(^.*}\\s-*$\\)")
                          ;; previous line closed a block, indent to that line
                          (current-indentation))
                         ((looking-at "\\(^.*[,>]\\s-*$\\)")
                          ;; previous line finishes a statement - in this case
                          ;; we want to indent by the block depth
                          (* (apparmor-mode--block-depth) apparmor-mode-indent-offset))
                         ((looking-at "\\(^.*[^,>]\\s-*$\\)")
                          ;; previous line doesn't finish in a comma or > - if it
                          ;; is the start of a statement (ie. the
                          ;; previous-previous finishes in a comma) then indent
                          ;; by more otherwise indent by the same
                          (if (save-excursion
                                (apparmor-mode--find-first-previous-non-blank-line)
                                (or (bobp) (looking-at "\\(^.*[,{}>]\\s-*$\\)")))
                              (+ (current-indentation) (* 2 apparmor-mode-indent-offset))
                            (current-indentation)))
                         (t
                          ;; default case, indent based on block depth of the
                          ;; original position
                          (goto-char orig)
                          (* (apparmor-mode--block-depth) apparmor-mode-indent-offset)))))))))

;;;###autoload
(define-derived-mode apparmor-mode prog-mode "AppArmor"
  "apparmor-mode is a major mode for editing AppArmor profiles."
  :syntax-table apparmor-mode-syntax-table
  (setq font-lock-defaults apparmor-mode-font-lock-defaults)
  (setq-local indent-line-function #'apparmor-mode-indent-line)
  (add-to-list 'completion-at-point-functions #'apparmor-mode-completion-at-point)
  (setq imenu-generic-expression `(("Profiles" ,apparmor-mode-profile-regexp 5)))
  (setq comment-start "#")
  (setq comment-end "")
  (when (require 'flycheck nil t)
    (unless (flycheck-valid-checker-p 'apparmor)
      (flycheck-define-command-checker 'apparmor
        "A checker using apparmor_parser. "
        :command '("apparmor_parser"
                  "-Q" ;; skip kernel load
                  "-K" ;; skip cache
                  source)
        :error-patterns '((error line-start "AppArmor parser error at line "
                                 line ": " (message)
                                line-end)
                          (error line-start "AppArmor parser error for "
                                 (one-or-more not-newline)
                                 " in profile " (file-name)
                                 " at line " line ": " (message)
                                line-end))
        :modes '(apparmor-mode)))
    (add-to-list 'flycheck-checkers 'apparmor t)))

;; flymake integration
(defvar-local apparmor-mode--flymake-proc nil)

(defun apparmor-mode-flymake (report-fn &rest _args)
  "`flymake' backend function for `apparmor-mode' to report errors via REPORT-FN."
  ;; disable if apparmor_parser is not available
  (unless (executable-find "apparmor_parser")
    (error "Cannot find apparmor_parser"))

  ;; kill any existing running instance
  (when (process-live-p apparmor-mode--flymake-proc)
    (kill-process apparmor-mode--flymake-proc))

  (let ((source (current-buffer))
        (contents (buffer-substring (point-min) (point-max))))
    ;; when the current buffer is an abstraction then fake a profile around it so
    ;; we can check it
    (when (and (buffer-file-name)
               (string-match-p ".*/abstractions/.*" (buffer-file-name)))
      (setq contents (format "profile %s { %s }" (buffer-name) contents)))
    (save-restriction
      (widen)
      ;; Reset the `apparmor-mode--flymake-proc' process to a new process
      ;; calling check-syntax.
      (setq
       apparmor-mode--flymake-proc
       (make-process
        :name "apparmor-mode-flymake" :noquery t :connection-type 'pipe
        ;; Make output go to a temporary buffer.
        :buffer (generate-new-buffer " *apparmor-mode-flymake*")
        ;; TODO: specify the base directory so that includes resolve correctly
        ;; rather than using the system ones
        :command '("apparmor_parser" "-Q" "-K" "/dev/stdin")
        :sentinel
        (lambda (proc _event)
          (when (memq (process-status proc) '(exit signal))
            (unwind-protect
                ;; Only proceed if `proc' is the same as
                ;; `apparmor-mode--flymake-proc', which indicates that
                ;; `proc' is not an obsolete process.
                ;;
                (if (with-current-buffer source (eq proc apparmor-mode--flymake-proc))
                    (with-current-buffer (process-buffer proc)
                      (goto-char (point-min))
                      ;; Parse the output buffer for diagnostic's
                      ;; messages and locations, collect them in a list
                      ;; of objects, and call `report-fn'.
                      ;;
                      (cl-loop
                       while (search-forward-regexp
                              "^\\(AppArmor parser error \\(?:for /dev/stdin in profile .*\\)?at line \\)\\([0-9]+\\): \\(.*\\)$"
                              nil t)
                       for msg = (match-string 3)
                       for (beg . end) = (flymake-diag-region
                                          source
                                          (string-to-number (match-string 2)))
                       for type = :error
                       collect (flymake-make-diagnostic source beg end type msg)
                       into diags
                       finally (funcall report-fn diags)))
                  (flymake-log :warning "Cancelling obsolete check %s" proc))
              ;; Cleanup the temporary buffer used to hold the
              ;; check's output.
              (kill-buffer (process-buffer proc)))))))
      (process-send-string apparmor-mode--flymake-proc contents)
      (process-send-eof apparmor-mode--flymake-proc))))

;;;###autoload
(defun apparmor-mode-setup-flymake-backend ()
  "Setup the `flymake' backend for `apparmor-mode'."
  (add-hook 'flymake-diagnostic-functions 'apparmor-mode-flymake nil t))

;;;###autoload
(add-hook 'apparmor-mode-hook 'apparmor-mode-setup-flymake-backend)

;;;###autoload
(add-to-list 'auto-mode-alist '("\\`/etc/apparmor\\.d/" . apparmor-mode))
;;;###autoload
(add-to-list 'auto-mode-alist '("\\`/var/lib/snapd/apparmor/profiles/" . apparmor-mode))


(provide 'apparmor-mode)
;;; apparmor-mode.el ends here
