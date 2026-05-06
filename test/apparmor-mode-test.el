(require 'ert)
(require 'apparmor-mode)

;;; Helpers

(defun apparmor-mode-test--face-at (str target)
  "Return the face at the start of TARGET within a buffer containing STR in apparmor-mode."
  (with-temp-buffer
    (apparmor-mode)
    (insert str)
    (font-lock-ensure)
    (goto-char (point-min))
    (search-forward target)
    (get-text-property (match-beginning 0) 'face)))

;;; Indentation tests

(ert-deftest apparmor-mode-indent-dbus ()
  "Test that dbus rules are indented correctly."
  (with-temp-buffer
    (apparmor-mode)
    (insert "
dbus (send)
bus=session,
")
    (indent-region (point-min) (point-max))
    (should (string= (buffer-substring-no-properties (point-min) (point-max))
                     "
dbus (send)
    bus=session,
"))))

(ert-deftest apparmor-mode-indent-blocks ()
  "Test that block rules are indented correctly."
  (with-temp-buffer
    (apparmor-mode)
    (insert "
{
dbus (send)
bus=session,
}")
    (indent-region (point-min) (point-max))
    (should (string= (buffer-substring-no-properties (point-min) (point-max)) "
{
  dbus (send)
      bus=session,
}"))))

(ert-deftest apparmor-mode-indent-with-alternations ()
  "Test that AAREs with alternations are indented correctly."
  (with-temp-buffer
    (apparmor-mode)
    (insert "
{
  /dev/{,urandom,null} r,
}")
    (indent-region (point-min) (point-max))
    (should (string= (buffer-substring-no-properties (point-min) (point-max)) "
{
  /dev/{,urandom,null} r,
}"))))

(ert-deftest apparmor-mode-indent-file-rule-with-profile-transition ()
  "Test that rules that specify a profile transition indent correctly."
  (with-temp-buffer
    (apparmor-mode)
    (insert "
{
  file Cx /usr/libexec/rygel/mx-extract -> mx-extract,
  file mrix /usr/lib/@{multiarch}/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner,
  file r /usr/share/gupnp-dlna-2.0/dlna-profiles/{,*},
}")
    (indent-region (point-min) (point-max))
    (should (string= (buffer-substring-no-properties (point-min) (point-max)) "
{
  file Cx /usr/libexec/rygel/mx-extract -> mx-extract,
  file mrix /usr/lib/@{multiarch}/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner,
  file r /usr/share/gupnp-dlna-2.0/dlna-profiles/{,*},
}"))))

(ert-deftest apparmor-mode-indent-profile-with-flags ()
  "Test that a profile header with flags=(unconfined) indents its body correctly.
Based on profiles such as /etc/apparmor.d/busybox and /etc/apparmor.d/devhelp."
  (with-temp-buffer
    (apparmor-mode)
    (insert "
profile busybox /usr/bin/busybox flags=(unconfined) {
userns,
/usr/bin/busybox mr,
}")
    (indent-region (point-min) (point-max))
    (should (string= (buffer-substring-no-properties (point-min) (point-max)) "
profile busybox /usr/bin/busybox flags=(unconfined) {
  userns,
  /usr/bin/busybox mr,
}"))))

(ert-deftest apparmor-mode-indent-file-rules-with-variables ()
  "Test that file rules using @{} variable references indent correctly.
Based on rules from /etc/apparmor.d/abstractions/base and /etc/apparmor.d/alsamixer."
  (with-temp-buffer
    (apparmor-mode)
    (insert "
{
/usr/lib/@{multiarch}/gconv/*.so mr,
@{etc_ro}/ld.so.cache mr,
@{HOME}/.config r,
}")
    (indent-region (point-min) (point-max))
    (should (string= (buffer-substring-no-properties (point-min) (point-max)) "
{
  /usr/lib/@{multiarch}/gconv/*.so mr,
  @{etc_ro}/ld.so.cache mr,
  @{HOME}/.config r,
}"))))

(ert-deftest apparmor-mode-indent-network-rules ()
  "Test that network rules indent correctly.
Based on rules from /etc/apparmor.d/dig."
  (with-temp-buffer
    (apparmor-mode)
    (insert "
{
network inet dgram,
network inet6 dgram,
network inet stream,
}")
    (indent-region (point-min) (point-max))
    (should (string= (buffer-substring-no-properties (point-min) (point-max)) "
{
  network inet dgram,
  network inet6 dgram,
  network inet stream,
}"))))

(ert-deftest apparmor-mode-indent-capability-rules ()
  "Test that capability rules indent correctly.
Based on rules from /etc/apparmor.d/dig."
  (with-temp-buffer
    (apparmor-mode)
    (insert "
{
capability dac_override,
capability dac_read_search,
}")
    (indent-region (point-min) (point-max))
    (should (string= (buffer-substring-no-properties (point-min) (point-max)) "
{
  capability dac_override,
  capability dac_read_search,
}"))))

(ert-deftest apparmor-mode-indent-multiline-dbus-rule ()
  "Test that multi-line dbus rules indent continuation lines correctly.
Based on rules from /etc/apparmor.d/abstractions/dbus-strict."
  (with-temp-buffer
    (apparmor-mode)
    (insert "
{
  dbus send
       bus=session
       path=/org/freedesktop/DBus
       interface=org.freedesktop.DBus
       member=Hello
       peer=(name=org.freedesktop.DBus),
}")
    (indent-region (point-min) (point-max))
    (should (string= (buffer-substring-no-properties (point-min) (point-max)) "
{
  dbus send
      bus=session
      path=/org/freedesktop/DBus
      interface=org.freedesktop.DBus
      member=Hello
      peer=(name=org.freedesktop.DBus),
}"))))

(ert-deftest apparmor-mode-indent-nested-profiles ()
  "Test that nested profile blocks indent correctly.
Based on /etc/apparmor.d/bwrap-userns-restrict which has multiple profiles."
  (with-temp-buffer
    (apparmor-mode)
    (insert "
profile outer /usr/bin/outer {
allow file rwlkm /{**,},
profile inner /usr/bin/inner {
allow network,
}
}")
    (indent-region (point-min) (point-max))
    (should (string= (buffer-substring-no-properties (point-min) (point-max)) "
profile outer /usr/bin/outer {
  allow file rwlkm /{**,},
  profile inner /usr/bin/inner {
    allow network,
  }
}"))))

;;; Font-lock tests

(ert-deftest apparmor-mode-font-lock-keywords ()
  "Test that AppArmor keywords receive font-lock-keyword-face."
  (should (eq (apparmor-mode-test--face-at "capability dac_override," "capability")
              'font-lock-keyword-face))
  (should (eq (apparmor-mode-test--face-at "network inet dgram," "network")
              'font-lock-keyword-face))
  (should (eq (apparmor-mode-test--face-at "dbus (send) bus=session," "dbus")
              'font-lock-keyword-face))
  (should (eq (apparmor-mode-test--face-at "file r /etc/passwd," "file")
              'font-lock-keyword-face))
  (should (eq (apparmor-mode-test--face-at "deny /etc/shadow r," "deny")
              'font-lock-keyword-face))
  (should (eq (apparmor-mode-test--face-at "userns," "userns")
              'font-lock-keyword-face)))

(ert-deftest apparmor-mode-font-lock-include-directive ()
  "Test that include directives are fontified correctly.
Based on includes found throughout /etc/apparmor.d/."
  (should (eq (apparmor-mode-test--face-at "include <abstractions/base>" "include")
              'font-lock-preprocessor-face))
  (should (eq (apparmor-mode-test--face-at "include <tunables/global>" "include")
              'font-lock-preprocessor-face))
  (should (eq (apparmor-mode-test--face-at "include <abstractions/base>" "abstractions/base")
              'font-lock-string-face))
  (should (eq (apparmor-mode-test--face-at "include if exists <local/dig>" "include")
              'font-lock-preprocessor-face))
  (should (eq (apparmor-mode-test--face-at "include if exists <local/dig>" "local/dig")
              'font-lock-string-face)))

(ert-deftest apparmor-mode-font-lock-abi-directive ()
  "Test that abi directives are fontified correctly.
Based on abi declarations found throughout /etc/apparmor.d/."
  (should (eq (apparmor-mode-test--face-at "abi <abi/5.0>," "abi")
              'font-lock-preprocessor-face))
  (should (eq (apparmor-mode-test--face-at "abi <abi/5.0>," "abi/5.0")
              'font-lock-string-face)))

(ert-deftest apparmor-mode-font-lock-variable-reference ()
  "Test that @{} variable references receive font-lock-variable-name-face.
Based on variables used throughout /etc/apparmor.d/."
  (should (eq (apparmor-mode-test--face-at "/usr/lib/@{multiarch}/gconv/*.so mr," "@{multiarch}")
              'font-lock-variable-name-face))
  (should (eq (apparmor-mode-test--face-at "owner @{HOME}/.config r," "@{HOME}")
              'font-lock-variable-name-face))
  (should (eq (apparmor-mode-test--face-at "@{etc_ro}/ld.so.cache mr," "@{etc_ro}")
              'font-lock-variable-name-face))
  ;; variable references inside comments must keep the comment face, not be
  ;; overridden by the variable-name face
  (should (eq (apparmor-mode-test--face-at "# allow @{HOME}" "@{HOME}")
              'font-lock-comment-face)))

(ert-deftest apparmor-mode-font-lock-capability-type ()
  "Test that capability types receive font-lock-type-face.
Based on capability rules from /etc/apparmor.d/dig and /etc/apparmor.d/abstractions/."
  (should (eq (apparmor-mode-test--face-at "capability dac_override," "dac_override")
              'font-lock-type-face))
  (should (eq (apparmor-mode-test--face-at "capability dac_read_search," "dac_read_search")
              'font-lock-type-face))
  (should (eq (apparmor-mode-test--face-at "capability sys_admin," "sys_admin")
              'font-lock-type-face)))

(ert-deftest apparmor-mode-font-lock-profile-name ()
  "Test that profile names and attachments are fontified correctly.
Based on profile declarations from /etc/apparmor.d/dig and /etc/apparmor.d/alsamixer."
  (should (eq (apparmor-mode-test--face-at "profile dig /usr/bin/dig {" "dig")
              'font-lock-function-name-face))
  (should (eq (apparmor-mode-test--face-at "profile dig /usr/bin/dig {" "/usr/bin/dig")
              'font-lock-variable-name-face))
  (should (eq (apparmor-mode-test--face-at "profile alsamixer /{usr,}/bin/alsamixer {" "alsamixer")
              'font-lock-function-name-face)))

(ert-deftest apparmor-mode-font-lock-file-permissions ()
  "Test that file rule permissions receive font-lock-constant-face.
Based on file rules from /etc/apparmor.d/dig and /etc/apparmor.d/abstractions/base."
  ;; permissions-before-path (prefix) form: file <perms> <path>,
  (should (eq (apparmor-mode-test--face-at "file r /etc/passwd," "r")
              'font-lock-constant-face))
  (should (eq (apparmor-mode-test--face-at "file mr /usr/bin/dig," "mr")
              'font-lock-constant-face))
  ;; permissions-after-path (suffix) form: <path> <perms>,
  (should (eq (apparmor-mode-test--face-at "/usr/bin/dig mr," "mr")
              'font-lock-constant-face))
  (should (eq (apparmor-mode-test--face-at "/etc/passwd r," "r")
              'font-lock-constant-face)))

(ert-deftest apparmor-mode-font-lock-operators ()
  "Test that -> and trailing commas receive font-lock-builtin-face.
Based on rules from /etc/apparmor.d/abstractions/base and transition rules."
  (should (eq (apparmor-mode-test--face-at "file Cx /path -> child," "->")
              'font-lock-builtin-face))
  (should (eq (apparmor-mode-test--face-at "/path r," ",")
              'font-lock-builtin-face)))

(ert-deftest apparmor-mode-font-lock-quoted-path ()
  "Test font-locking of file rules with quoted paths (for filenames with spaces).
Quoted paths allow spaces in filenames, e.g. files under @{HOME}/My Documents/."
  ;; suffix form: \"path\" perms,
  (should (eq (apparmor-mode-test--face-at "\"@{HOME}/My Documents/file\" rw," "@{HOME}")
              'font-lock-variable-name-face))
  (should (eq (apparmor-mode-test--face-at "\"@{HOME}/My Documents/file\" rw," "rw")
              'font-lock-constant-face))
  ;; prefix form: file perms \"path\",
  (should (eq (apparmor-mode-test--face-at "file rw \"@{HOME}/My Documents/file\"," "@{HOME}")
              'font-lock-variable-name-face))
  (should (eq (apparmor-mode-test--face-at "file rw \"@{HOME}/My Documents/file\"," "rw")
              'font-lock-constant-face))
  ;; mixed form: file \"path\" perms,
  (should (eq (apparmor-mode-test--face-at "file \"@{HOME}/My Documents/file\" rw," "@{HOME}")
              'font-lock-variable-name-face))
  (should (eq (apparmor-mode-test--face-at "file \"@{HOME}/My Documents/file\" rw," "rw")
              'font-lock-constant-face))
  ;; quoted path without a variable reference
  (should (eq (apparmor-mode-test--face-at "\"/path/with spaces\" r," "r")
              'font-lock-constant-face))
  ;; profile transition with a quoted source path
  (should (eq (apparmor-mode-test--face-at "file Cx \"/path/with spaces\" -> child," "Cx")
              'font-lock-constant-face)))

(ert-deftest apparmor-mode-font-lock-glob-chars ()
  "Test that AARE glob characters in paths are fontified correctly.
* ** ? receive font-lock-regexp-grouping-construct; { } receive font-lock-builtin-face.
Based on path patterns from /etc/apparmor.d/abstractions/base and /etc/apparmor.d/alsamixer."
  ;; * wildcard in suffix form file rule
  (should (eq (apparmor-mode-test--face-at "/usr/lib/*/file mr," "*")
              'font-lock-regexp-grouping-construct))
  ;; ** wildcard in suffix form file rule
  (should (eq (apparmor-mode-test--face-at "/usr/bin/** mr," "*")
              'font-lock-regexp-grouping-construct))
  ;; { and } in alternation in suffix form file rule
  (should (eq (apparmor-mode-test--face-at "/dev/{urandom,null} r," "{")
              'font-lock-builtin-face))
  (should (eq (apparmor-mode-test--face-at "/dev/{urandom,null} r," "}")
              'font-lock-builtin-face))
  ;; * wildcard in prefix form file rule
  (should (eq (apparmor-mode-test--face-at "file r /usr/lib/*.so," "*")
              'font-lock-regexp-grouping-construct))
  ;; { and } in alternation in profile attachment
  (should (eq (apparmor-mode-test--face-at "profile alsamixer /{usr,}/bin/alsamixer {" "{")
              'font-lock-builtin-face))
  ;; { and } of @{} variable references must NOT be glob builtins
  (should (eq (apparmor-mode-test--face-at "@{HOME}/*.so mr," "{")
              'font-lock-variable-name-face))
  (should (eq (apparmor-mode-test--face-at "@{HOME}/*.so mr," "}")
              'font-lock-variable-name-face))
  ;; * after a variable reference is still a glob wildcard
  (should (eq (apparmor-mode-test--face-at "@{HOME}/*.so mr," "*")
              'font-lock-regexp-grouping-construct))
  ;; ? wildcard matches a single character in a path
  (should (eq (apparmor-mode-test--face-at "/usr/lib/libfoo.so.? mr," "?")
              'font-lock-regexp-grouping-construct)))
