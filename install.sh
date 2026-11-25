#!/usr/bin/env bash
set -euo pipefail

# Colored installer UI; automatically disabled when stdout is not a terminal.
if [[ -t 1 ]]; then
  C_RESET=[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash install.sh"; exit 1; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# When installing from a Git checkout, fast-forward to the latest main before
# using any bundled files. Refuse dirty/non-main checkouts rather than
# overwriting local work or installing an unintended branch.
if [[ -d "$SCRIPT_DIR/.git" && "${SLIPSTREAM_INSTALLER_UPDATED:-0}" != "1" ]]; then
  command -v git >/dev/null 2>&1 || { echo "ERROR: git is required to update this checkout."; exit 1; }
  GIT_SAFE=(git -c "safe.directory=$SCRIPT_DIR" -C "$SCRIPT_DIR")
  if [[ -n "$("${GIT_SAFE[@]}" status --porcelain)" ]]; then
    echo "ERROR: repository has local changes; commit/stash them before installing."
    exit 1
  fi
  CURRENT_BRANCH="$("${GIT_SAFE[@]}" branch --show-current)"
  if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo "ERROR: installer checkout is on '$CURRENT_BRANCH', not 'main'."
    echo "Switch to main and run the installer again."
    exit 1
  fi
  "${GIT_SAFE[@]}" fetch --quiet origin main || { echo "ERROR: could not fetch latest main from origin."; exit 1; }
  "${GIT_SAFE[@]}" pull --ff-only --quiet origin main || { echo "ERROR: could not fast-forward to origin/main."; exit 1; }
  export SLIPSTREAM_INSTALLER_UPDATED=1
  exec bash "$SCRIPT_DIR/install.sh" "$@"
fi

APP=/opt/slipstream-panel
CONF=/etc/slipstream-panel
BIN="${SLIPSTREAM_BIN:-/usr/local/bin/slipstream-client}"
[[ "$BIN" == /* && "$BIN" != *[[:space:]]* ]] || { echo "SLIPSTREAM_BIN must be an absolute path without whitespace."; exit 1; }

# Verify that stage two only tests DNS resolvers that replied to ICMP in stage one.
if ! grep -Fq "ping_success={item['resolver'] for item in DNS_SCAN_STATE['ping_results'] if item.get('ok')}" "$SCRIPT_DIR/app.py" ||
   ! grep -Fq 'candidates=[resolver for resolver in resolvers if resolver in ping_success]' "$SCRIPT_DIR/app.py"; then
  echo "ERROR: app.py does not contain the ping-filtered two-stage DNS scanner."
  echo "Please download the latest repository version and run install.sh again."
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-flask openssl iputils-ping ca-certificates curl
python3 - "$SCRIPT_DIR/app.py" <<'PY'
import ast, sys
from pathlib import Path
if sys.version_info < (3, 9):
    raise SystemExit("ERROR: Python 3.9 or newer is required.")
try:
    import flask
except Exception as exc:
    raise SystemExit(f"ERROR: Flask is not importable by the system Python: {exc}")
source = Path(sys.argv[1]).read_text(encoding="utf-8")
ast.parse(source, filename=sys.argv[1])
print(f"Python {sys.version.split()[0]} and Flask are ready; app.py syntax is valid.")
PY
install -d -m 0750 "$APP" "$CONF"

install -d -m 0755 "$(dirname "$BIN")"

# Create the unprivileged account used by per-tunnel systemd services.
if ! getent group slipstream >/dev/null; then
  groupadd --system slipstream
fi
if ! id -u slipstream >/dev/null 2>&1; then
  useradd --system --gid slipstream --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin slipstream
fi
install -d -o slipstream -g slipstream -m 0750 /var/log/slipstream-panel

# Keep existing settings when reinstalling; prompt for new values only when needed.
DEFAULT_PORT="$(cat "$CONF/panel.port" 2>/dev/null || echo 18080)"
printf "\\033[1;36m\\033[1m▶ Panel port\\033[0m [${DEFAULT_PORT}]: "; read -r PANEL_PORT
PANEL_PORT="${PANEL_PORT:-$DEFAULT_PORT}"
[[ "$PANEL_PORT" =~ ^[0-9]+$ ]] && (( PANEL_PORT >= 1 && PANEL_PORT <= 65535 )) || { echo "Invalid TCP port."; exit 1; }
if [[ "$PANEL_PORT" != "$DEFAULT_PORT" ]] && command -v ss >/dev/null 2>&1 && ss -lntH "sport = :$PANEL_PORT" | grep -q .; then
  echo "Port $PANEL_PORT is already in use."; exit 1
fi

SUGGESTED_PATH="$(openssl rand -hex 8)"
DEFAULT_PATH="$(cat "$CONF/base-path" 2>/dev/null | sed 's#^/##' || true)"
DEFAULT_PATH="${DEFAULT_PATH:-$SUGGESTED_PATH}"
echo "Suggested private URL path: /$SUGGESTED_PATH"
printf "\\033[1;36m\\033[1m▶ Panel URL path\\033[0m [${DEFAULT_PATH}]: "; read -r PANEL_PATH
PANEL_PATH="${PANEL_PATH:-$DEFAULT_PATH}"
[[ "$PANEL_PATH" =~ ^[A-Za-z0-9_-]{4,64}$ ]] || { echo "Path must be 4-64 characters: letters, numbers, _ or -. Do not include slashes."; exit 1; }

if [[ -s "$CONF/admin.password" ]]; then
  printf "\\033[1;36m\\033[1m▶ Keep existing admin password?\\033[0m [Y/n]: "; read -r KEEP_PASSWORD
else
  KEEP_PASSWORD="n"
fi
if [[ "${KEEP_PASSWORD:-Y}" =~ ^[Nn]$ ]]; then
  while true; do
    printf "\\033[1;36m\\033[1m▶ Choose admin password (min 12 characters; empty = generate one): \\033[0m"; read -r -s ADMIN_PASSWORD; echo
    if [[ -z "$ADMIN_PASSWORD" ]]; then
      ADMIN_PASSWORD="$(openssl rand -base64 32 | tr -d '\n')"
      GENERATED_PASSWORD=1
      break
    fi
    (( ${#ADMIN_PASSWORD} >= 12 )) || { echo "Password must be at least 12 characters."; continue; }
    printf "\\033[1;36m\\033[1m▶ Confirm admin password: \\033[0m"; read -r -s ADMIN_PASSWORD_CONFIRM; echo
    [[ "$ADMIN_PASSWORD" == "$ADMIN_PASSWORD_CONFIRM" ]] && break
    echo "Passwords do not match. Try again."
  done
  umask 077
  printf '%s' "$ADMIN_PASSWORD" > "$CONF/admin.password"
  chmod 600 "$CONF/admin.password"
fi

# Always deploy the app.py shipped beside this installer (including scanner fixes).
install -m 0750 "$SCRIPT_DIR/app.py" "$APP/app.py"
echo "Installed DNS scanner: stage two is limited to IPs that passed stage-one ping."

# Always download the Linux AMD64 executable from the latest upstream GitHub Release.

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

download_slipstream_binary

# Install the standalone Slipstream manager and its systemd unit.
install -m 0750 "$SCRIPT_DIR/slip-manager.py" "$APP/slip-manager.py"
install -d -m 0755 /etc/systemd/system
install -m 0644 "$SCRIPT_DIR/systemd/slip.service" /etc/systemd/system/slip.service
install -d -m 0755 /var/log/slipstream

chown -R root:root "$APP"
printf '%s' "$PANEL_PORT" > "$CONF/panel.port"
printf '/%s' "$PANEL_PATH" > "$CONF/base-path"
chmod 600 "$CONF/panel.port" "$CONF/base-path"

[[ -f "$CONF/secret.key" ]] || {
  openssl rand -hex 32 > "$CONF/secret.key"
  chmod 600 "$CONF/secret.key"
}

cat > /etc/systemd/system/slipstream-panel.service <<EOF2
[Unit]
Description=Slipstream Web Panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$APP
Environment=PANEL_HOST=0.0.0.0
Environment=PANEL_PORT=$PANEL_PORT
Environment=SLIPSTREAM_BIN=$BIN
ExecStart=/usr/bin/python3 $APP/app.py
Restart=always
RestartSec=3
User=root
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF2

systemctl daemon-reload
systemctl enable slipstream-panel
systemctl restart slipstream-panel || systemctl start slipstream-panel

if [[ "${SLIPSTREAM_ENABLE_STANDALONE:-0}" == "1" ]]; then
  if [[ -x "$BIN" ]]; then
    systemctl enable --now slip.service
    echo "Standalone Slipstream service enabled and started. Review its target in slip.service first."
  else
    echo "ERROR: standalone service requested, but $BIN is missing or not executable."
    exit 1
  fi
else
  echo "Standalone slip.service was installed but left disabled; the panel does not require it."
  echo "Review systemd/slip.service and its target before enabling it manually."
fi

# Detect the public IPv4 address for a ready-to-copy panel URL.
SERVER_IP=""
if command -v curl >/dev/null 2>&1; then SERVER_IP="$(curl -4fsS --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null || true)"; fi
if [[ ! "$SERVER_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"; fi
PANEL_URL="http://${SERVER_IP:-SERVER_IP}:${PANEL_PORT}/${PANEL_PATH}/"
echo
printf "\\033[1;32m\\033[1m✓ Slipstream Panel installed successfully!\\033[0m\\n"
printf "\\033[1;36m\\033[1mOpen this address in your browser:\\033[0m\\n"
printf "\\033[1;32m╔══════════════════════════════════════════════════════════════════╗\\033[0m\\n"
printf "\\033[1;32m║\\033[0m \\033[1;33m\\033[1m%s\\033[0m\\n" "$PANEL_URL"
printf "\\033[1;32m╚══════════════════════════════════════════════════════════════════╝\\033[0m\\n"
if [[ "${GENERATED_PASSWORD:-0}" == 1 ]]; then
  printf "\\033[1;33mAdmin password (save it securely):\\033[0m %s\\n" "$ADMIN_PASSWORD"
else
  echo "Admin password: configured (stored in $CONF/admin.password)"
fi
echo "Panel port: $PANEL_PORT"
echo "URL path: /$PANEL_PATH/"
if [[ ! -x "$BIN" ]]; then
  echo "NOTICE: Slipstream client binary was not found at $BIN."
  echo "Install the Slipstream client separately to use tunnel-management features."
fi
echo "IMPORTANT: Restrict TCP/$PANEL_PORT to trusted IP addresses in your firewall and use HTTPS through a reverse proxy when exposing it publicly."
