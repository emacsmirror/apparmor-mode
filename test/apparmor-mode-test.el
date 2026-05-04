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
