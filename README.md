# Multi-Client Slipstream Panel with Load Balancer & DNS Scanner

<p align="center">
  <strong>🇬🇧 English</strong> · <a href="README.fa.md">🇮🇷 فارسی</a>
</p>

<img width="1408" height="768" alt="Slipstream Panel screenshot" src="https://github.com/user-attachments/assets/fed4fb2d-00fa-4fb8-a1ee-730c54b16757" />

A self-hosted web panel for running, monitoring, and managing multiple Slipstream client tunnels on Linux servers.

### ✨ Features
- **Tunnel management:** Add, configure, start, stop, restart, delete, and monitor multiple Slipstream tunnels.
- **systemd integration:** Automatically create and manage a separate systemd service for each tunnel.
- **DNS management:** Configure multiple DNS resolvers per tunnel, set global defaults, or apply DNS settings to all existing tunnels. Supports `IP:PORT` entries.
- **Advanced DNS scanner:** Two-stage testing with ICMP Ping and full Slipstream tunnel tests, SOCKS5 Username/Password authentication, Google HTTPS verification, TLS validation, HTTP 204 checking, latency measurement, configurable workers, and selectable results.
- **SOCKS5 load balancer:** Round Robin distribution across healthy active tunnels, automatic exclusion of unhealthy backends, recovery after cooldown, and SOCKS5 authentication forwarding.
- **Traffic monitoring:** Per-tunnel incoming/outgoing traffic, total usage, approximate speed, and traffic counter reset. Uses systemd per-service IP accounting.
- **Connection health monitoring:** Detect connection-ready, connection-closed, and client-error events; display failures; allow a recovery window; and automatically restart failed tunnels after cooldown.
- **Logs and security:** Per-tunnel logs, password-protected panel, CSRF protection, and separate application configuration/secrets.
- **Deployment:** Installation and update scripts for Ubuntu/Debian-based systems.

### 🧰 Requirements
- Ubuntu or Debian-based Linux server.
- Root or sudo access.
- Python 3 and Flask.
- The Slipstream client binary is bundled in the repository and installed automatically.

### 🚀 Quick Installation

Log in as root (use `sudo -i` if needed). Git is not required:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moeinfire/multi-client-slipstream-load-balancer/master/install-online.sh)
```

The online installer downloads the latest archive from the `master` branch and runs the project installer. It requires `curl` and installs other missing download tools when possible.

### 🗑️ Complete Uninstallation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moeinfire/multi-client-slipstream-load-balancer/master/uninstall.sh)
```

The uninstaller asks you to type `REMOVE` before deleting anything. To skip confirmation:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moeinfire/multi-client-slipstream-load-balancer/master/uninstall.sh) --yes
```

The uninstaller removes the panel service, matching project-generated tunnel services, application files, database, credentials/configuration, project logs, and the Slipstream binary recorded by the installer. It leaves external certificates, firewall rules, unrelated services, and system-wide packages (including Python/Flask) untouched. The dedicated `slipstream` account/group is removed only if it matches the installer-created account and is not in use.

### ⚠️ Important Notes
- Tunnel configurations and generated systemd tunnel services are created on the server; they are not included in the repository.
- Configure your own domains, DNS resolvers, certificates, and tunnel settings.
- Do not expose the panel directly to the public internet without appropriate access restrictions and HTTPS.
- Review the source code and security configuration before production use.

### 📄 License
MIT License


---

<p align="center">🇬🇧 English · <a href="README.fa.md">🇮🇷 فارسی</a> · <a href="#multi-client-slipstream-panel-with-load-balancer--dns-scanner">⬆ Back to top</a></p>
