# Multi-Client Slipstream Panel with Load Balancer & DNS Scanner

<p align="center">
  <a href="#english">🇬🇧 English</a> · <a href="#فارسی">🇮🇷 فارسی</a>
</p>

<img width="1408" height="768" alt="Slipstream Panel screenshot" src="https://github.com/user-attachments/assets/fed4fb2d-00fa-4fb8-a1ee-730c54b16757" />

<a id="english"></a>
<details open>
<summary><strong>🇬🇧 English</strong></summary>

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

</details>

<a id="فارسی"></a>
<details>
<summary><strong>🇮🇷 فارسی</strong></summary>

یک پنل مدیریتی تحت وب و قابل میزبانی روی سرور شخصی برای راه‌اندازی، نظارت و مدیریت چندین تونل Slipstream Client در سرورهای لینوکسی.

### ✨ امکانات
- **مدیریت تونل‌ها:** افزودن، پیکربندی، شروع، توقف، راه‌اندازی مجدد، حذف و نظارت بر چندین تونل Slipstream.
- **یکپارچگی با systemd:** ساخت و مدیریت خودکار یک سرویس systemd مجزا برای هر تونل.
- **مدیریت DNS:** تنظیم چند DNS Resolver برای هر تونل، تعیین DNS پیش‌فرض سراسری یا اعمال تنظیمات روی تمام تونل‌های موجود. پشتیبانی از فرمت `IP:PORT`.
- **اسکنر پیشرفته DNS:** آزمایش دومرحله‌ای شامل Ping از نوع ICMP و تست کامل تونل Slipstream، احراز هویت Username/Password در SOCKS5، بررسی HTTPS گوگل، اعتبارسنجی TLS، بررسی پاسخ HTTP 204، اندازه‌گیری تأخیر، تنظیم تعداد Worker و انتخاب نتایج.
- **لودبالانسر SOCKS5:** توزیع اتصال‌ها با روش Round Robin بین تونل‌های سالم و فعال، خارج کردن خودکار تونل‌های ناسالم از چرخه، بازگرداندن تونل پس از زمان بازیابی و انتقال احراز هویت SOCKS5.
- **پایش ترافیک:** نمایش ترافیک ورودی و خروجی هر تونل، حجم کل، سرعت تقریبی و امکان صفر کردن شمارنده ترافیک. مبتنی بر قابلیت IP Accounting در systemd برای هر سرویس.
- **پایش سلامت اتصال:** تشخیص پیام‌های connection ready، connection closed و client error؛ نمایش خطاها؛ در نظر گرفتن مهلت بازیابی و راه‌اندازی مجدد خودکار تونل‌های خراب پس از زمان انتظار.
- **لاگ و امنیت:** مشاهده لاگ اختصاصی هر تونل، پنل محافظت‌شده با رمز عبور، محافظت CSRF و ذخیره‌سازی جداگانه تنظیمات و اطلاعات محرمانه برنامه.
- **نصب و به‌روزرسانی:** اسکریپت‌های نصب و به‌روزرسانی برای سیستم‌های مبتنی بر Ubuntu و Debian.

### 🧰 پیش‌نیازها
- سرور لینوکسی مبتنی بر Ubuntu یا Debian.
- دسترسی Root یا Sudo.
- Python 3 و Flask.
- فایل اجرایی Slipstream Client داخل مخزن قرار دارد و به‌صورت خودکار نصب می‌شود.

### 🚀 نصب سریع

با کاربر Root وارد سرور شوید (در صورت نیاز `sudo -i` را اجرا کنید). نیازی به نصب Git نیست:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moeinfire/multi-client-slipstream-load-balancer/master/install-online.sh)
```

نصب‌کننده آنلاین آخرین آرشیو شاخه `master` را دریافت و نصب می‌کند. برای دریافت دستور به `curl` نیاز دارد و در صورت امکان ابزارهای دانلود موردنیاز دیگر را نیز نصب می‌کند.

### 🗑️ حذف کامل

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moeinfire/multi-client-slipstream-load-balancer/master/uninstall.sh)
```

اسکریپت حذف پیش از انجام عملیات از شما می‌خواهد عبارت `REMOVE` را وارد کنید. برای رد کردن مرحله تأیید:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moeinfire/multi-client-slipstream-load-balancer/master/uninstall.sh) --yes
```

اسکریپت حذف، سرویس پنل، سرویس‌های تونل ساخته‌شده توسط پروژه، فایل‌های برنامه، پایگاه داده، اطلاعات ورود و تنظیمات، لاگ‌های پروژه و فایل اجرایی Slipstream ثبت‌شده توسط نصب‌کننده را حذف می‌کند. فایل‌های گواهی خارجی، قوانین فایروال، سرویس‌های نامرتبط و بسته‌های سراسری سیستم (از جمله Python و Flask) دست‌نخورده باقی می‌مانند. حساب و گروه اختصاصی `slipstream` فقط در صورتی حذف می‌شوند که متعلق به همین نصب‌کننده باشند و در حال استفاده نباشند.

### ⚠️ نکات مهم
- تنظیمات تونل‌ها و سرویس‌های systemd تولیدشده روی سرور ایجاد می‌شوند و داخل مخزن قرار ندارند.
- دامنه‌ها، DNS Resolverها، گواهی‌ها و تنظیمات تونل را باید خودتان پیکربندی کنید.
- پنل را بدون محدودیت دسترسی مناسب و HTTPS مستقیماً در اینترنت عمومی قرار ندهید.
- پیش از استفاده عملیاتی، کد منبع و تنظیمات امنیتی را بررسی کنید.

### 📄 مجوز
MIT License

</details>

---

<p align="center">
  <a href="#english">🇬🇧 English</a> · <a href="#فارسی">🇮🇷 فارسی</a> · <a href="#multi-client-slipstream-panel-with-load-balancer--dns-scanner">⬆ Back to top</a>
</p>
