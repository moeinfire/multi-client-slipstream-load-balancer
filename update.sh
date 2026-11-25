#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash update.sh"; exit 1; }

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
APP=/opt/slipstream-panel
CONF=/etc/slipstream-panel
BIN="${SLIPSTREAM_BIN:-/usr/local/bin/slipstream-client}"
[[ "$BIN" == /* && "$BIN" != *[[:space:]]* ]] || { echo "SLIPSTREAM_BIN must be an absolute path without whitespace."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required to update the Slipstream binary."; exit 1; }

[[ -d "$APP" ]] || { echo "Panel not installed at $APP"; exit 1; }
[[ -s "$CONF/secret.key" && -s "$CONF/admin.password" ]] || {
  echo "Panel configuration or credentials are missing; refusing to update."
  exit 1
}
[[ -s "$SCRIPT_DIR/app.py" ]] || { echo "ERROR: Repository app.py is missing."; exit 1; }
[[ -s "$SCRIPT_DIR/socks5-gateway.py" ]] || { echo "ERROR: Repository socks5-gateway.py is missing."; exit 1; }

python3 - "$SCRIPT_DIR/app.py" "$SCRIPT_DIR/socks5-gateway.py" <<'PY'
import ast, sys
from pathlib import Path
if sys.version_info < (3, 9):
    raise SystemExit("ERROR: Python 3.9 or newer is required.")
try:
    import flask
except Exception as exc:
    raise SystemExit(f"ERROR: Flask is not importable by the system Python: {exc}")
for filename in sys.argv[1:]:
    source = Path(filename).read_text(encoding="utf-8")
    ast.parse(source, filename=filename)
app = Path(sys.argv[1]).read_text(encoding="utf-8")
if "ping_success={item['resolver']" not in app or "candidates=[resolver for resolver in resolvers if resolver in ping_success]" not in app:
    raise SystemExit("ERROR: app.py must restrict stage two to DNS IPs that passed stage-one ping.")
if "auth_enabled" not in app or "socks5-gateway.py" not in app:
    raise SystemExit("ERROR: app.py is missing the per-tunnel SOCKS5 authentication gateway integration.")
print("Python, Flask, app.py, gateway syntax, and DNS scanner checks passed.")
PY


download_slipstream_binary() {
  [[ "$(uname -m)" == "x86_64" ]] || {
    echo "ERROR: This project currently provides only the Linux AMD64 (x86_64) Slipstream binary."
    return 1
  }
  command -v curl >/dev/null 2>&1 || {
    echo "ERROR: curl is required to download the Slipstream binary."
    return 1
  }
  install -d -m 0755 "$(dirname "$BIN")"
  local tmp_bin
  tmp_bin="$(mktemp "${BIN}.download.XXXXXX")"
  if ! curl --fail --location --silent --show-error --retry 3 --connect-timeout 15 \
      "https://github.com/AliRezaBeigy/slipstream-rust-deploy/releases/latest/download/slipstream-client-linux-amd64" \
      --output "$tmp_bin"; then
    rm -f -- "$tmp_bin"
    echo "ERROR: Could not download the latest Slipstream Linux AMD64 binary."
    return 1
  fi
  if ! python3 - "$tmp_bin" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
h = p.read_bytes()[:20]
if len(h) < 20 or h[:4] != b"\x7fELF" or h[4] != 2:
    raise SystemExit("Downloaded file is not a 64-bit ELF executable.")
if h[5] not in (1, 2):
    raise SystemExit("Downloaded ELF has an unsupported byte order.")
endian = "little" if h[5] == 1 else "big"
if int.from_bytes(h[18:20], endian) != 62:
    raise SystemExit("Downloaded ELF is not an x86-64 (AMD64) executable.")
PY
  then
    rm -f -- "$tmp_bin"
    echo "ERROR: The downloaded Slipstream file failed Linux AMD64 validation."
    return 1
  fi
  chmod 0755 "$tmp_bin"
  if [[ -f "$BIN" ]] && cmp -s "$tmp_bin" "$BIN"; then
    rm -f -- "$tmp_bin"
    echo "Slipstream Linux AMD64 is already up to date."
  else
    mv -f -- "$tmp_bin" "$BIN"
    echo "Updated Slipstream Linux AMD64 binary: $BIN"
  fi
}

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
[[ -s "$APP/socks5-gateway.py" ]] || { echo "ERROR: Installed SOCKS5 gateway is missing; run install.sh for a safe migration."; exit 1; }
BIN_BACKUP=""
if [[ -f "$BIN" ]]; then
  BIN_BACKUP="$BIN.bak.$STAMP"
  cp -a "$BIN" "$BIN_BACKUP"
fi
download_slipstream_binary
BACKUP="$APP/app.py.bak.$STAMP"
GATEWAY_BACKUP="$APP/socks5-gateway.py.bak.$STAMP"
TEMP="$APP/.app.py.new"
GATEWAY_TEMP="$APP/.socks5-gateway.py.new"
cp -a "$APP/app.py" "$BACKUP"
cp -a "$APP/socks5-gateway.py" "$GATEWAY_BACKUP"
install -m 0750 "$SCRIPT_DIR/app.py" "$TEMP"
install -m 0750 "$SCRIPT_DIR/socks5-gateway.py" "$GATEWAY_TEMP"
chown root:root "$TEMP" "$GATEWAY_TEMP"
python3 - "$TEMP" "$GATEWAY_TEMP" <<'PY'
import ast, sys
from pathlib import Path
for filename in sys.argv[1:]:
    ast.parse(Path(filename).read_text(encoding="utf-8"), filename=filename)
PY
mv -f "$TEMP" "$APP/app.py"
mv -f "$GATEWAY_TEMP" "$APP/socks5-gateway.py"

if ! systemctl restart slipstream-panel || ! systemctl is-active --quiet slipstream-panel; then
  echo "Panel restart failed; restoring the previous app.py."
  cp -a "$BACKUP" "$APP/app.py"
  cp -a "$GATEWAY_BACKUP" "$APP/socks5-gateway.py"
  if [[ -n "$BIN_BACKUP" && -f "$BIN_BACKUP" ]]; then cp -a "$BIN_BACKUP" "$BIN"; fi
  systemctl restart slipstream-panel || true
  echo "Previous file restored from $BACKUP"
  journalctl -u slipstream-panel -n 60 --no-pager || true
  exit 1
fi

echo "Panel updated successfully."
echo "App backup: $BACKUP"
echo "Gateway backup: $GATEWAY_BACKUP"
systemctl --no-pager --full status slipstream-panel
