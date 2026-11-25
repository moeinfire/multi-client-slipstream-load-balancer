#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash install.sh"; exit 1; }

# Terminal colors for clear installer prompts.
if [[ -t 1 ]]; then
  CYAN="$(tput setaf 6 2>/dev/null || true)"
  YELLOW="$(tput setaf 3 2>/dev/null || true)"
  GREEN="$(tput setaf 2 2>/dev/null || true)"
  BOLD="$(tput bold 2>/dev/null || true)"
  RESET="$(tput sgr0 2>/dev/null || true)"
else
  CYAN=''; YELLOW=''; GREEN=''; BOLD=''; RESET=''
fi


SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Support both local installation and one-command online installation.
# If this script was launched remotely, download the project source and re-run
# this same installer from the extracted archive.
if [[ ! -f "$SCRIPT_DIR/app.py" || ! -f "$SCRIPT_DIR/slip-manager.py" ]]; then
  if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    echo "Installing required download tools..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl tar ca-certificates
  fi

  TMP_DIR="$(mktemp -d -t slipstream-panel-install.XXXXXX)"
  trap 'rm -rf -- "$TMP_DIR"' EXIT
  ARCHIVE="$TMP_DIR/source.tar.gz"
  SOURCE_DIR="$TMP_DIR/source"
  mkdir -p "$SOURCE_DIR"

  echo "Downloading the latest Slipstream Panel source from GitHub..."
  curl --fail --location --silent --show-error --retry 3 \
    "https://github.com/moeinfire/multi-client-slipstream-load-balancer/archive/refs/heads/master.tar.gz" \
    --output "$ARCHIVE"

  echo "Extracting project files..."
  tar -xzf "$ARCHIVE" --strip-components=1 -C "$SOURCE_DIR"

  for file in install.sh app.py slip-manager.py; do
    if [[ ! -f "$SOURCE_DIR/$file" ]]; then
      echo "ERROR: Required project file is missing from the downloaded archive: $file"
      exit 1
    fi
  done

  echo "Source archive verified. Starting the project installer..."
  SLIPSTREAM_INSTALLER_BOOTSTRAPPED=1 bash "$SOURCE_DIR/install.sh" "$@"
  exit $?
fi

APP=/opt/slipstream-panel
CONF=/etc/slipstream-panel
BIN="${SLIPSTREAM_BIN:-/usr/local/bin/slipstream-client}"
[[ "$BIN" == /* && "$BIN" != *[[:space:]]* ]] || { echo "SLIPSTREAM_BIN must be an absolute path without whitespace."; exit 1; }

# Do not couple installation to exact DNS scanner source-code expressions.
# app.py is validated below for Python syntax and runtime dependencies.

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
read -r -p "${BOLD}${CYAN}▶ Panel port ${YELLOW}[${DEFAULT_PORT}]${RESET}: " PANEL_PORT
PANEL_PORT="${PANEL_PORT:-$DEFAULT_PORT}"
[[ "$PANEL_PORT" =~ ^[0-9]+$ ]] && (( PANEL_PORT >= 1 && PANEL_PORT <= 65535 )) || { echo "Invalid TCP port."; exit 1; }
if [[ "$PANEL_PORT" != "$DEFAULT_PORT" ]] && command -v ss >/dev/null 2>&1 && ss -lntH "sport = :$PANEL_PORT" | grep -q .; then
  echo "Port $PANEL_PORT is already in use."; exit 1
fi

SUGGESTED_PATH="$(openssl rand -hex 8)"
DEFAULT_PATH="$(cat "$CONF/base-path" 2>/dev/null | sed 's#^/##' || true)"
DEFAULT_PATH="${DEFAULT_PATH:-$SUGGESTED_PATH}"
echo "Suggested private URL path: /$SUGGESTED_PATH"
read -r -p "${BOLD}${CYAN}▶ Panel URL path ${YELLOW}[${DEFAULT_PATH}]${RESET}: " PANEL_PATH
PANEL_PATH="${PANEL_PATH:-$DEFAULT_PATH}"
[[ "$PANEL_PATH" =~ ^[A-Za-z0-9_-]{4,64}$ ]] || { echo "Path must be 4-64 characters: letters, numbers, _ or -. Do not include slashes."; exit 1; }

if [[ -s "$CONF/admin.password" ]]; then
  read -r -p "${BOLD}${CYAN}▶ Keep existing admin password? ${YELLOW}[Y/n]${RESET}: " KEEP_PASSWORD
else
  KEEP_PASSWORD="n"
fi
if [[ "${KEEP_PASSWORD:-Y}" =~ ^[Nn]$ ]]; then
  while true; do
    read -r -s -p "${BOLD}${CYAN}▶ Choose admin password (min 12 characters; empty = generate one): ${RESET}" ADMIN_PASSWORD; echo
    if [[ -z "$ADMIN_PASSWORD" ]]; then
      ADMIN_PASSWORD="$(openssl rand -base64 32 | tr -d '\n')"
      GENERATED_PASSWORD=1
      break
    fi
    (( ${#ADMIN_PASSWORD} >= 12 )) || { echo "Password must be at least 12 characters."; continue; }
    read -r -s -p "${BOLD}${CYAN}▶ Confirm admin password: ${RESET}" ADMIN_PASSWORD_CONFIRM; echo
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

# Install the standalone Slipstream manager.
install -m 0750 "$SCRIPT_DIR/slip-manager.py" "$APP/slip-manager.py"
install -d -m 0755 /etc/systemd/system
install -d -m 0755 /var/log/slipstream

# Generate the standalone systemd unit directly from this installer.
cat > /etc/systemd/system/slip.service <<'EOF_SLIP_UNIT'
[Unit]
Description=Slipstream Standalone Manager
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=SLIPSTREAM_BIN=/usr/local/bin/slipstream-client
Environment=SLIPSTREAM_RESOLVER=8.8.8.8:53
Environment=SLIPSTREAM_TARGETS=r.2222.ir:20817
Environment=SLIPSTREAM_LOGDIR=/var/log/slipstream
ExecStart=/usr/bin/python3 -u /opt/slipstream-panel/slip-manager.py
Restart=always
RestartSec=5
KillSignal=SIGTERM
TimeoutStopSec=15
User=root
WorkingDirectory=/opt/slipstream-panel

[Install]
WantedBy=multi-user.target
EOF_SLIP_UNIT
chmod 0644 /etc/systemd/system/slip.service

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

echo
echo "Slipstream Panel installed."
SERVER_IP="$(curl -4fsS --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null || true)"
if [[ -z "$SERVER_IP" ]]; then SERVER_IP="$(hostname -I 2>/dev/null | cut -d " " -f1)"; fi
PANEL_URL="http://${SERVER_IP:-SERVER_IP}:${PANEL_PORT}/${PANEL_PATH}/"
printf "%s\n" "${GREEN}╔══════════════════════════════════════════════════════════════════╗${RESET}"
printf "%s\n" "${GREEN}║ ${BOLD}${YELLOW}${PANEL_URL}${RESET}${GREEN} ║${RESET}"
printf "%s\n" "${GREEN}╚══════════════════════════════════════════════════════════════════╝${RESET}"
if [[ "${GENERATED_PASSWORD:-0}" == 1 ]]; then
  echo "Generated admin password: $ADMIN_PASSWORD"
else
  echo "Admin password: configured (stored in $CONF/admin.password)"
fi
echo "Panel port: $PANEL_PORT (stored in $CONF/panel.port)"
echo "URL path: /$PANEL_PATH/ (stored in $CONF/base-path)"
if [[ ! -x "$BIN" ]]; then
  echo "NOTICE: Slipstream client binary was not found at $BIN."
  echo "Install the Slipstream client separately to use tunnel-management features."
fi
echo "IMPORTANT: Restrict TCP/$PANEL_PORT to trusted IP addresses in your firewall and use HTTPS through a reverse proxy when exposing it publicly."
