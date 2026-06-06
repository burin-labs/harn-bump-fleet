#!/usr/bin/env bash
set -euo pipefail

# install_sccache_keepalive.sh — install + (re)load the sccache keepalive
# LaunchAgent (see scripts/sccache_keepalive.sh for the why). Idempotent:
# safe to re-run after editing the script or plist template.
#
# Usage:
#   scripts/install_sccache_keepalive.sh           # install + load
#   scripts/install_sccache_keepalive.sh --uninstall

self_dir="$(cd "$(dirname "$0")" && pwd)"
label="com.burincode.sccache-keepalive"
script="$self_dir/sccache_keepalive.sh"
template="$self_dir/$label.plist.template"
plist="$HOME/Library/LaunchAgents/$label.plist"
domain="gui/$(id -u)"

unload() {
  launchctl bootout "$domain/$label" 2>/dev/null \
    || launchctl unload "$plist" 2>/dev/null \
    || true
}

if [ "${1:-}" = "--uninstall" ]; then
  unload
  rm -f "$plist"
  echo "Uninstalled $label"
  exit 0
fi

[ -f "$template" ] || { echo "missing template: $template" >&2; exit 1; }
chmod +x "$script"
mkdir -p "$HOME/Library/LaunchAgents"
sed "s#__SCRIPT__#$script#g" "$template" > "$plist"

unload
launchctl bootstrap "$domain" "$plist" 2>/dev/null || launchctl load "$plist"
# Force an immediate run so the daemon is claimed now, not just next login.
launchctl kickstart -k "$domain/$label" 2>/dev/null || true

echo "Installed and loaded $label"
echo "  plist : $plist"
echo "  log   : /tmp/sccache-keepalive.log"
