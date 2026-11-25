<div align="center">

# Multi-Client Slipstream Panel with Load Balancer & DNS Scanner

**[🇬🇧 English Version](#-english-version)** • **[🇮🇷 نسخه فارسی](#-نسخه-فارسی)**

</div>

---

<a id="-english-version"></a>

# 🇬🇧 English Version

> **[🇮🇷 نسخه فارسی](#-نسخه-فارسی)**

<img width="1408" height="768" alt="Slipstream Panel screenshot" src="https://github.com/user-attachments/assets/fed4fb2d-00fa-4fb8-a1ee-730c54b16757" />

A self-hosted web-based management panel for running, monitoring, and managing multiple Slipstream client tunnels on Linux servers.

Slipstream Panel provides a centralized web interface for managing tunnel instances, configuring DNS resolvers, monitoring connection health, tracking traffic usage, and distributing SOCKS5 connections across healthy tunnels.

## ✨ Features

### 🚇 Tunnel Management

- Add and configure multiple Slipstream client instances.
- Automatically create and manage systemd services for tunnel instances.
- Start, stop, restart, and delete individual tunnels.
- Perform bulk operations to start, stop, or restart multiple tunnels.
- Configure a local listening port for each tunnel.
- Enable or disable SOCKS5 authentication independently for each tunnel, with its own username and password.
- Apply shared SOCKS5 authentication credentials to all domains added in one bulk operation.
- Optional PEM certificate path configuration.
- View individual tunnel logs for troubleshooting.

### 🌐 DNS Management

- Configure multiple DNS resolvers for each tunnel.
- Set global default DNS resolvers for newly created tunnels.
- Apply DNS configuration to all existing tunnels.
- Edit DNS settings independently for each tunnel.
- Support multiple resolver entries in `IP:PORT` format.


## 🔍 Advanced DNS Scanner

- Two-stage DNS testing workflow.
- First-stage ICMP Ping testing for DNS resolver IPs.
- Second-stage end-to-end Slipstream tunnel testing.
- SOCKS5 Username/Password authentication during the test.
- Toggle scanner authentication on or off to test authenticated or no-auth SOCKS5 endpoints.
- Stage two tests only DNS resolver IPs that passed the stage-one ICMP ping.
- HTTPS connectivity verification against Google.
- TLS certificate validation and HTTP 204 response verification.
- Measure end-to-end latency and sort successful DNS results.
- Configurable worker count and test timeout.
- Select and copy successful DNS resolver addresses.
- Temporary test tunnels do not modify or restart existing production tunnels.

### ⚖️ SOCKS5 Load Balancer

- Built-in SOCKS5 load balancer.
- Round Robin distribution for new connections.
- Automatically select healthy and active tunnel backends.
- Temporarily exclude unhealthy or unreachable tunnels.
- Reintroduce recovered tunnels after the cooldown period.
- Keep client-side panel authentication independent from the authentication required by the remote SOCKS5 server.
- When panel authentication is enabled, validate the client's Username/Password against the tunnel settings. If the remote server requires RFC1929, the gateway sends the saved panel credentials; if the remote server selects No Auth, the gateway completes the local login and continues without sending credentials upstream.
- When panel authentication is disabled, negotiate the methods offered by the client and accepted by the remote server, forwarding client-supplied RFC1929 credentials when required.
- Restrict access to trusted IPv4/IPv6 addresses or CIDR ranges using the load-balancer allowlist.

### 📊 Traffic Monitoring

- Monitor incoming and outgoing traffic for each tunnel.
- Display total traffic usage per instance.
- Calculate approximate transfer speeds using periodic sampling.
- Reset traffic counters for individual tunnels.
- Traffic accounting based on systemd per-service IP accounting.

### ❤️ Connection Health Monitoring

- Periodically inspect each tunnel's service logs.
- Detect connection-ready, connection-closed, and client-error events.
- Display connection status and failure information.
- Allow a recovery window before declaring a tunnel failed.
- Automatically restart failed tunnels after a cooldown period.
- Detect process exits and address-in-use errors.

### 🔐 Access and Deployment

- Password-protected web interface.
- CSRF protection for management actions.
- Automatically generated initial administrator password.
- Separate storage for application secrets and configuration.
- systemd service integration.
- Installation and update scripts for Ubuntu/Debian-based systems.

## 🧰 Requirements

- Ubuntu or Debian-based Linux server.
- Root or sudo access.
- Python 3.
- Flask.
- The installer downloads only the Linux AMD64 Slipstream client binary from the latest release of `AliRezaBeigy/slipstream-rust-deploy` and installs it automatically.

## 🚀 Quick Installation (One Command)

Run this single command on an Ubuntu/Debian server (Git is not required):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moeinfire/multi-client-slipstream-load-balancer/master/install.sh)
```

The online installer downloads the latest `master` branch archive and runs the project installer. `curl` must be available to start the command; the bootstrap installs `tar` and CA certificates if needed. Run it as root; if you are not already root, open a root shell first with `sudo -i`.

## 🗑️ Complete Uninstallation

To remove the panel and resources created by this project directly from an Ubuntu or Debian server, run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moeinfire/multi-client-slipstream-load-balancer/master/uninstall.sh)
```

The uninstaller asks for explicit confirmation by requiring the word `REMOVE`. To run without an interactive prompt:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moeinfire/multi-client-slipstream-load-balancer/master/uninstall.sh) --yes
```

It stops and removes the panel service, the optional standalone `slip.service` (only when its service file matches this project), and tunnel services generated by the panel. It also removes the panel application, database, credentials/configuration, project log directories, and the Slipstream client binary at the path recorded by the installer.

For safety, external certificate files, firewall rules, unrelated services, and system-wide packages (including Python/Flask) are left untouched. The dedicated `slipstream` system account/group is removed only when its settings match the account created by this installer and it is not in use.

## ⚠️ Important Notes

- The Slipstream client binary is downloaded from the latest `AliRezaBeigy/slipstream-rust-deploy` GitHub Release (`slipstream-client-linux-amd64`); `update.sh` fetches the latest release asset whenever the panel is updated.
- Tunnel configurations and systemd tunnel services are not included.
- Each user must configure their own domains, DNS resolvers, certificates, and tunnel settings.
- The panel should not be exposed directly to the public internet without appropriate access restrictions and HTTPS protection.
- Review the source code and security configuration before deploying in production.

## 📄 License

MIT License
---

<a id="-نسخه-فارسی"></a>

<div dir="rtl">


# 🇮🇷 نسخه فارسی

> **[🇬🇧 Switch to English](#-english-version)**

# پنل مدیریت چندکلاینتی Slipstream با لودبالانسر و اسکنر DNS

یک پنل مدیریتی تحت وب و قابل میزبانی روی سرور شخصی برای اجرا، نظارت و مدیریت چندین تونل Slipstream Client روی سرورهای لینوکسی.

Slipstream Panel یک رابط وب متمرکز برای مدیریت نمونه‌های تونل، پیکربندی DNS Resolverها، نظارت بر سلامت اتصال، پیگیری میزان مصرف ترافیک و توزیع اتصال‌های SOCKS5 بین تونل‌های سالم فراهم می‌کند.

### 🔐 API خارجی مدیریت اعتبارنامه تونل

برای تغییر یا حذف نام کاربری و رمز SOCKS5 مقصد هر تونل، API احراز هویت‌شده در دسترس است. پنل و رابط وب از یک مسیر مشترک برای بازسازی تونل استفاده می‌کنند. پس از تغییر، تونل شناسه جدید می‌گیرد؛ دامنه، DNSها، پورت محلی، گواهی، وضعیت فعال/متوقف و سایر تنظیمات تونل حفظ می‌شوند. هنگام بازسازی، اتصال‌های جاری همان تونل ممکن است قطع شوند.

احراز هویت: رمز مدیریت پنل را در هدر `X-API-Key` یا به‌صورت توکن `Bearer` در هدر `Authorization` بفرستید. برای استفاده از کلید جداگانه، متغیر محیطی `SLIPSTREAM_API_TOKEN` را در محیط سرویس پنل تنظیم کنید؛ در صورت تنظیم‌نشدن، رمز مدیریت پنل به‌عنوان کلید API استفاده می‌شود.

تغییر اعتبارنامه:

```http
PUT /api/tunnels/12/credentials
X-API-Key: YOUR_API_TOKEN
Content-Type: application/json

{"username":"socks-user","password":"socks-password"}
```

پاسخ موفق شامل `ok`، `changed`، شناسه قبلی در `previous_id` و شناسه جدید در `id` است. برای درخواست‌های بعدی از شناسه جدید استفاده کنید.

حذف اعتبارنامه و غیرفعال‌کردن احراز هویت مقصد:

```http
DELETE /api/tunnels/12/credentials
X-API-Key: YOUR_API_TOKEN
```

متد `PATCH` نیز با همان JSON متد `PUT` پشتیبانی می‌شود. برای تغییر، هر دو فیلد نام کاربری و رمز باید غیرخالی باشند؛ برای حذف، از `DELETE` استفاده کنید. کدهای پاسخ: `401` احراز هویت ناموفق، `404` تونل ناموجود، `400` ورودی نامعتبر و `500` خطا در بازسازی یا بازیابی تونل.



## ✨ امکانات

### 🚇 مدیریت تونل‌ها

- افزودن و پیکربندی چندین نمونه Slipstream Client.
- ایجاد و مدیریت خودکار سرویس‌های systemd برای نمونه‌های تونل.
- شروع، توقف، راه‌اندازی مجدد و حذف جداگانه هر تونل.
- اجرای عملیات گروهی برای شروع، توقف یا راه‌اندازی مجدد چندین تونل.
- تنظیم پورت شنونده محلی برای هر تونل.
- فعال یا غیرفعال‌سازی مستقل احراز هویت SOCKS5 برای هر تونل، همراه با نام کاربری و رمز عبور اختصاصی.
- اعمال نام کاربری و رمز مشترک SOCKS5 روی تمام دامنه‌هایی که به‌صورت گروهی اضافه می‌شوند.
- امکان تنظیم مسیر گواهی PEM.
- مشاهده لاگ اختصاصی هر تونل برای عیب‌یابی.

### 🔑 API خارجی مدیریت اعتبارنامه تونل

- امکان تغییر یا حذف اعتبارنامه SOCKS5 مقصد هر تونل بدون ورود به فرم پنل.
- آدرس: `/api/tunnels/{tunnel_id}/credentials`
- احراز هویت: رمز مدیر پنل را در هدر `X-API-Key` یا `Authorization: Bearer <token>` ارسال کنید. توکن همان رمز ذخیره‌شده در فایل `/etc/slipstream-panel/admin.password` است.
- برای تغییر اعتبارنامه از متد `PUT` یا `PATCH` و بدنه JSON شامل دو رشته غیرخالی `username` و `password` استفاده کنید.
- برای حذف کامل اعتبارنامه از متد `DELETE` استفاده کنید؛ رمز خالی را برای حذف ارسال نکنید.
- پس از تغییر موفق، تونل با شناسه جدید بازسازی می‌شود. دامنه، DNSها، پورت محلی، گواهی و وضعیت فعال/متوقف حفظ می‌شوند. اتصال‌های جاری آن تونل در زمان جایگزینی قطع خواهند شد.
- پاسخ API شامل `previous_id` و شناسه جدید `id` است؛ اگر سامانه خارجی شناسه تونل را ذخیره می‌کند، باید آن را به‌روزرسانی کند.
- عملیات تغییر در Workerهای برنامه سریالی می‌شود. در صورت شکست بازسازی، برنامه تلاش می‌کند رکورد و سرویس قبلی را بازیابی کند. دیتابیس و systemd تراکنش اتمیک مشترک ندارند؛ بنابراین اگر پاسخ خطا از شکست Rollback نیز خبر داد، وضعیت سرویس را بررسی کنید.
- این API را فقط پشت HTTPS و محدودیت دسترسی Firewall قرار دهید. توکن همان رمز مدیر پنل است؛ آن را در کد سمت کاربر یا لاگ‌ها قرار ندهید.

نمونه تغییر اعتبارنامه:

```bash
curl -X PUT "https://PANEL_HOST/api/tunnels/12/credentials" \
  -H "X-API-Key: YOUR_PANEL_ADMIN_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"username":"SOCKS_USER","password":"SOCKS_PASSWORD"}'
```

نمونه حذف اعتبارنامه:

```bash
curl -X DELETE "https://PANEL_HOST/api/tunnels/12/credentials" \
  -H "X-API-Key: YOUR_PANEL_ADMIN_PASSWORD"
```

### 🌐 مدیریت DNS

- پیکربندی چند DNS Resolver برای هر تونل.
- تعیین DNS Resolverهای پیش‌فرض سراسری برای تونل‌های جدید.
- اعمال تنظیمات DNS روی تمام تونل‌های موجود.
- ویرایش مستقل تنظیمات DNS برای هر تونل.
- پشتیبانی از چند Resolver با فرمت `IP:PORT`.

### 🔍 اسکنر پیشرفته DNS

- روند آزمایش DNS در دو مرحله.
- مرحله اول: آزمایش Ping از نوع ICMP برای IP آدرس DNS Resolverها.
- مرحله دوم: آزمایش کامل و انتها‌به‌انتهای تونل Slipstream.
- پشتیبانی از احراز هویت Username/Password در SOCKS5 هنگام آزمایش.
- امکان فعال یا غیرفعال کردن احراز هویت در اسکنر برای آزمایش SOCKS5 با رمز یا بدون احراز هویت.
- در مرحله دوم فقط DNSهایی آزمایش می‌شوند که در مرحله اول Ping موفق داشته‌اند.
- بررسی اتصال HTTPS به سرویس Google.
- اعتبارسنجی گواهی TLS و بررسی پاسخ HTTP 204.
- اندازه‌گیری تأخیر انتها‌به‌انتها و مرتب‌سازی نتایج موفق DNS.
- امکان تنظیم تعداد Workerها و زمان Timeout آزمایش.
- انتخاب و کپی آدرس DNS Resolverهای موفق.
- تونل‌های موقت آزمایش، تونل‌های عملیاتی موجود را تغییر نمی‌دهند و باعث راه‌اندازی مجدد آن‌ها نمی‌شوند.

### ⚖️ لودبالانسر SOCKS5

- لودبالانسر داخلی SOCKS5.
- توزیع اتصال‌های جدید با روش Round Robin.
- انتخاب خودکار Backendهای تونل سالم و فعال.
- خارج کردن موقت تونل‌های ناسالم یا غیرقابل دسترس از چرخه.
- بازگرداندن تونل‌های بازیابی‌شده پس از پایان زمان Cooldown.
- احراز هویت کلاینت در پنل از روش احراز هویت موردنیاز SOCKS5 مقصد مستقل است.
- با فعال بودن احراز هویت پنل، Username/Password کلاینت با اطلاعات همان تونل بررسی می‌شود. اگر سرور مقصد RFC1929 بخواهد، Gateway اطلاعات ذخیره‌شده پنل را ارسال می‌کند؛ اگر مقصد No Auth انتخاب کند، ورود محلی تأیید می‌شود و ادامه اتصال بدون ارسال رمز به مقصد انجام می‌گیرد.
- با غیرفعال بودن احراز هویت پنل، روش‌های اعلام‌شده از طرف کلاینت و پشتیبانی‌شده توسط سرور مقصد مذاکره می‌شوند و در صورت نیاز، اطلاعات RFC1929 کلاینت به مقصد منتقل می‌شود.
- دسترسی لودبالانسر با فهرست IPهای مجاز IPv4/IPv6 و محدوده‌های CIDR محدود می‌شود.

### 📊 پایش ترافیک

- پایش ترافیک ورودی و خروجی هر تونل.
- نمایش حجم کل ترافیک مصرف‌شده هر نمونه.
- محاسبه سرعت تقریبی انتقال داده با نمونه‌برداری دوره‌ای.
- صفر کردن شمارنده ترافیک هر تونل به‌صورت مستقل.
- محاسبه ترافیک بر اساس قابلیت IP Accounting در systemd برای هر سرویس.

### ❤️ پایش سلامت اتصال

- بررسی دوره‌ای لاگ سرویس هر تونل.
- تشخیص رویدادهای connection-ready، connection-closed و client-error.
- نمایش وضعیت اتصال و اطلاعات مربوط به خطاها.
- در نظر گرفتن مهلت بازیابی پیش از اعلام خرابی تونل.
- راه‌اندازی مجدد خودکار تونل‌های خراب پس از پایان زمان Cooldown.
- تشخیص خارج شدن پردازش از اجرا و خطاهای اشغال بودن آدرس (Address in Use).

### 🔐 دسترسی و استقرار

- رابط وب محافظت‌شده با رمز عبور.
- محافظت CSRF برای عملیات مدیریتی.
- تولید خودکار رمز عبور اولیه مدیر پنل.
- ذخیره‌سازی جداگانه اطلاعات محرمانه و تنظیمات برنامه.
- یکپارچگی با سرویس systemd.
- اسکریپت‌های نصب و به‌روزرسانی برای سیستم‌های مبتنی بر Ubuntu/Debian.

## 🧰 پیش‌نیازها

- سرور لینوکسی مبتنی بر Ubuntu یا Debian.
- دسترسی Root یا Sudo.
- Python 3.
- Flask.
- نصب‌کننده فقط فایل اجرایی Slipstream Client مخصوص Linux AMD64 را از آخرین Release مخزن `AliRezaBeigy/slipstream-rust-deploy` دریافت و نصب می‌کند.

## 🚀 نصب سریع (با یک دستور)

این دستور را روی سرور Ubuntu/Debian اجرا کنید (نیازی به نصب Git نیست):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moeinfire/multi-client-slipstream-load-balancer/master/install-online.sh)
```

نصب‌کننده آنلاین آخرین آرشیو شاخه `master` را دریافت کرده و نصب‌کننده پروژه را اجرا می‌کند. برای شروع اجرای دستور، وجود `curl` ضروری است؛ اسکریپت راه‌انداز در صورت نیاز `tar` و گواهی‌های CA را نصب می‌کند. دستور را با دسترسی Root اجرا کنید؛ اگر در حال حاضر Root نیستید، ابتدا با دستور `sudo -i` وارد محیط Root شوید.

## 🗑️ حذف کامل

برای حذف پنل و منابع ایجادشده توسط این پروژه از سرور Ubuntu یا Debian، دستور زیر را اجرا کنید:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moeinfire/multi-client-slipstream-load-balancer/master/uninstall.sh)
```

اسکریپت حذف برای تأیید عملیات از شما می‌خواهد کلمه `REMOVE` را وارد کنید. برای اجرای حذف بدون نمایش درخواست تأیید:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/moeinfire/multi-client-slipstream-load-balancer/master/uninstall.sh) --yes
```

این اسکریپت سرویس پنل، سرویس مستقل و اختیاری `slip.service` (فقط در صورتی که فایل سرویس با این پروژه مطابقت داشته باشد) و سرویس‌های تونلی ساخته‌شده توسط پنل را متوقف و حذف می‌کند. همچنین برنامه پنل، پایگاه داده، اطلاعات ورود و تنظیمات، پوشه‌های لاگ پروژه و فایل اجرایی Slipstream Client را در مسیری که توسط نصب‌کننده ثبت شده است حذف می‌کند.

برای حفظ امنیت، فایل‌های گواهی خارجی، قوانین فایروال، سرویس‌های نامرتبط و بسته‌های سراسری سیستم (از جمله Python/Flask) دست‌نخورده باقی می‌مانند. حساب و گروه سیستمی اختصاصی `slipstream` فقط زمانی حذف می‌شوند که تنظیمات آن‌ها با حساب ساخته‌شده توسط این نصب‌کننده مطابقت داشته باشد و در حال استفاده نباشند.

## ⚠️ نکات مهم

- فایل اجرایی Slipstream Client از آخرین Release مخزن `AliRezaBeigy/slipstream-rust-deploy` (با نام `slipstream-client-linux-amd64`) دریافت می‌شود و اسکریپت `update.sh` نیز هنگام به‌روزرسانی پروژه، آخرین نسخه Release را دریافت می‌کند.
- تنظیمات تونل‌ها و سرویس‌های systemd مربوط به تونل‌ها داخل مخزن قرار ندارند.
- هر کاربر باید دامنه‌ها، DNS Resolverها، گواهی‌ها و تنظیمات تونل خود را پیکربندی کند.
- پنل نباید بدون محدودیت دسترسی مناسب و محافظت HTTPS مستقیماً در معرض اینترنت عمومی قرار بگیرد.
- پیش از استفاده در محیط عملیاتی، کد منبع و تنظیمات امنیتی را بررسی کنید.

## 📄 مجوز

MIT License

</div>
