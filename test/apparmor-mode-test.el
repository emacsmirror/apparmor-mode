(require 'ert)
(require 'apparmor-mode)

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
