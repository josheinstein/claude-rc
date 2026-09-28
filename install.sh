#!/usr/bin/env bash
# Install claude-rc: scripts into ~/.local/bin, units into ~/.config/systemd/user,
# a starter config if none exists, then enable the boot-time sync service.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

install -d "$HOME/.local/bin" "$HOME/.config/systemd/user" "$HOME/.config/claude-rc"
install -m 755 "$here"/bin/claude-rc-ctl "$here"/bin/claude-rc-add "$here"/bin/claude-rc-interrupted "$HOME/.local/bin/"
install -m 644 "$here"/systemd/claude-rc.service "$here"/systemd/claude-rc@.service "$HOME/.config/systemd/user/"
if [[ ! -e "$HOME/.config/claude-rc/sessions.conf" ]]; then
  install -m 644 "$here/sessions.conf.example" "$HOME/.config/claude-rc/sessions.conf"
  echo "Created ~/.config/claude-rc/sessions.conf from the example — edit it before syncing."
fi

command -v claude >/dev/null || echo "WARNING: 'claude' not on PATH in a login shell; sessions will fail to start." >&2

systemctl --user daemon-reload
systemctl --user enable claude-rc.service
# Keep the user manager (and therefore the sessions) alive without an active login.
if [[ $(loginctl show-user "$USER" -p Linger --value 2>/dev/null) != yes ]]; then
  echo "Enabling lingering so sessions run at boot without a login (may prompt for sudo)."
  sudo loginctl enable-linger "$USER" || echo "WARNING: could not enable lingering; run: sudo loginctl enable-linger $USER" >&2
fi

echo
echo "Installed. Next:"
echo "  1. Add directories:   claude-rc-add            (from inside each directory)"
echo "     or edit:           ~/.config/claude-rc/sessions.conf"
echo "  2. Trust each dir:    run 'claude' there once and accept the trust dialog"
echo "  3. Apply:             claude-rc-ctl sync   (claude-rc-add does this for you)"
echo "  4. Check:             claude-rc-ctl list"
