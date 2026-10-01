> **این پروژه فقط روی Google WiFi AC-1304 (Gale) با OpenWrt 25.12.5 تست شده است. سایر مدل‌ها و نسخه‌های فریمور بررسی نشده‌اند.**

# RayWRT

[English](english.md) · [GitHub](https://github.com/Heygoodbye/RayWRT)

RayWRT یک پوسته تیره و سبز، داشبورد زنده و مجموعه ابزار LuCI است که برنامه‌های همراه ویندوز و اندروید نیز دارد. این پروژه توسط [Heygoodbye](https://github.com/Heygoodbye) ساخته شده، اطلاعات واقعی روتر را نمایش می‌دهد و صفحات اصلی OpenWrt را در دسترس نگه می‌دارد.

## سازگاری و وضعیت انتشار

| بخش | هدف |
| --- | --- |
| روتر | Google WiFi AC-1304 (Gale) |
| OpenWrt | 25.12.5 / r33051-f5dae5ece4 |
| تارگت و پروفایل | ipq40xx/chromium / google_wifi |
| بسته فریمور | RayWRT 1.0.0 |
| ویندوز | Windows x64، WPF / .NET |
| اندروید | اندروید ۸ یا جدیدتر |

ساخت ایمیج، بررسی متادیتا، محتوای فایل و checksum موفق بوده است. تست رسمی نصب تمیز با sysupgrade **در انتظار انجام** است؛ فریمور عمومی هنوز **کاملاً تأیید نشده** است. نسخه برنامه‌های همراه مستقل از فریمور است.

## رابط LuCI و داشبورد

- ظاهر تیره و سبز، کارت‌های گرد، سایه و امکان نمایش/مخفی کردن پس‌زمینه تزئینی.
- منوی کناری قابل جمع شدن در دسکتاپ، جست‌وجوی تنظیمات و زیرمنوهای برنامه‌های اصلی.
- چیدمان واکنش‌گرا و نوار شناور Home، Tools، Passwall، Terminal و More در موبایل.
- نمایش زنده CPU، حافظه، زمان روشن بودن، کل مصرف، نسخه فریمور/کرنل، ساعت، بار سیستم و فضای قابل نوشتن.
- وضعیت و IP رابط WAN، سرعت دانلود/آپلود و نمودار ترافیک اخیر.
- نمای شبکه و دستگاه‌های شناخته‌شده با IP، نوع اتصال، دانلود، آپلود و مصرف روزانه.
- وضعیت رادیوها و SSID، تنظیمات اصلی Wi-Fi، پشتیبان‌گیری/ارتقا و راه‌اندازی مجدد.

![داشبورد LuCI](docs/screenshots/dashboard.png)

شناسایی دستگاه از DHCP، همسایه‌های شبکه و اتصال Wi-Fi استفاده می‌کند. دستگاه ناشناخته با حدس شناسایی نمی‌شود. دما فقط با حسگر معتبر CPU/SoC نمایش داده می‌شود؛ Gale دمای معتبر CPU ندارد. Connected برای WAN وضعیت رابط است و تضمین اینترنت نیست.

## ابزارهای RayWRT

- کارت‌های دسترسی سریع و دسته‌بندی VPN، شبکه، سیستم، عیب‌یابی و ابزارهای پیشرفته.
- تشخیص جداگانه نصب بودن، پیکربندی و اجرای سرویس.
- تشخیص مدیر بسته و معماری، بررسی مخازن و فضای آزاد و نمایش گزارش نصب.
- نصب و مسیریابی در پس‌زمینه با گزارش پیشرفت برای جلوگیری از درخواست طولانی XHR.
- یکپارچه‌سازی Passwall 2، WireGuard، Xray، sing-box، OpenVPN و ttyd در صورت وجود بسته مناسب.
- میان‌بر رابط‌ها، مسیرها، فایروال، Wi-Fi، بسته‌ها، بکاپ، حافظه، فضای ذخیره‌سازی و لاگ‌ها.
- صفحه اصلی مدیریت OpenVPN و پشتیبانی پروتکل WireGuard در رابط‌های OpenWrt.

ابزارهای اختیاری بنا به درخواست نصب می‌شوند؛ حضور در فهرست به معنی نصب یا فعال بودن نیست. Passwall روی تارگت APK از مخزن امضاشده استفاده می‌کند و تعارض ip-tiny/ip-full در همان تراکنش مدیریت می‌شود. Passwall نصب‌شده حتی در حالت خاموش یا بدون پیکربندی Installed است.

![ابزارهای RayWRT](docs/screenshots/raywrt-tools.png)

![اطلاعات و ابزارهای سیستم](docs/screenshots/system-tools.png)

## مصرف اینترنت

مجموع WAN، دانلود/آپلود، آمار امروز، دیروز، ۷/۳۰ روز اخیر، مصرف هر دستگاه و تاریخچه روزانه. بخش‌های Overview، Devices، History، Diagnostics و Settings امکان تنظیم نگهداری و فاصله ذخیره و حذف تاریخچه با تأیید را می‌دهند. شمارنده زنده در RAM و مجموع روزانه به صورت دوره‌ای ذخیره می‌شود.

این آمار ثبت‌شده است و معادل صورتحساب شرکت اینترنت نیست. مصرف WAN و دستگاه‌ها ممکن است به دلیل ترافیک خود روتر و تفاوت انتساب به دستگاه متفاوت باشد.

![مصرف اینترنت](docs/screenshots/data-usage.png)

## WireGuard و مسیریابی مستقیم ایران

محدوده‌های **IPv4** ایران از WAN معمولی انتخاب‌شده عبور می‌کنند و سایر IPv4 مسیر پیش‌فرض WireGuard را دنبال می‌کند. انتخاب جداگانه تونل و WAN، دانلود و اعتبارسنجی فهرست ایران، نمایش تعداد محدوده‌ها، آخرین به‌روزرسانی و وضعیت مسیر فراهم است. جدول اختصاصی nftables و policy routing این قابلیت را مستقل از Passwall نگه می‌دارد. فهرست هنگام فعال بودن دوره‌ای به‌روز می‌شود.

Enable رابط full-tunnel انتخاب‌شده و مسیر پیش‌فرض را آماده می‌کند و اگر بررسی مسیر ناموفق باشد تغییرات فعال‌سازی را برمی‌گرداند. Disable یا حذف رابط انتخاب‌شده قوانین RayWRT را پاک می‌کند. IPv6 تغییر نمی‌کند. peer معتبر با `0.0.0.0/0`، endpoint قابل دسترس و فایروال مناسب لازم است. وضعیت رابط یا مسیر handshake اخیر را اثبات نمی‌کند. هیچ کلید، endpoint یا تنظیم شخصی Meli در فریمور نیست.

![مسیریابی مستقیم ایران](docs/screenshots/wireguard-iran-routing.png)

## ترمینال و عیب‌یابی

ترمینال root با ttyd و xterm.js داخل LuCI باز می‌شود و Connect، Disconnect/Stop، گزارش وضعیت و ظاهر واکنش‌گرا دارد. از نشست LuCI/RayWRT و helper چرخه ترمینال استفاده می‌کند. پس از پایان کار آن را متوقف کنید؛ دسترسی مدیریتی روتر دارد.

پینگ هم‌زمان از روتر برای سایت OpenWrt و endpointهای اروپایی World of Warcraft، League of Legends EUW/EUNE، Escape from Tarkov، World of Tanks، Fortnite آلمان/فرانسه/بریتانیا و PUBG اجرا می‌شود. نتایج شامل تأخیر، packet loss، پاسخ‌ها و میانگین/بازه برای چند endpoint است. نتایج قبلی هنگام Testing می‌مانند و آدرس خام بازی‌ها پشت برچسب سرور مخفی است. ICMP تضمین پینگ داخل بازی نیست.

![عیب‌یابی بازی‌ها](docs/screenshots/gaming-diagnostics.png)

## قابلیت‌های ویندوز و اندروید

| بخش | امکانات |
| --- | --- |
| اتصال روتر | ورود SSH، وضعیت اتصال، Refresh و تأیید fingerprint؛ رمز ذخیره نمی‌شود. |
| Passwall 2 | روشن/خاموش، تغییر نود، افزودن لینک نود یا subscription، آپدیت دستی subscription، حذف تنظیمات مجاز و باز کردن LuCI. |
| WireGuard | مشاهده/اتصال/قطع تونل، وارد کردن فایل `.conf` یا متن، افزودن رابط واردشده به zone فایروال WAN و هماهنگی تونل انتخاب‌شده با Iran Direct. |
| ابزارهای روتر | تست ۱۵ endpoint تنظیم‌شده، مدیریت Wi-Fi در ۲٫۴/۵ گیگاهرتز، تغییر SSID/رمز و reboot با تأیید. |
| طراحی | پنل‌های تیره و واکنش‌گرا، بررسی دوره‌ای اتصال و لینک سازنده؛ ویندوز پنجره بدون حاشیه و قابل جابه‌جایی و نصب portable/برای کاربر دارد. |

هر دو برنامه وضعیت واقعی UCI/ubus را با SSH می‌خوانند. مجموعه ۱۵ endpoint شامل سایت OpenWrt و سرورهای بازی اروپا است. SSH Connected تنها نشست و WireGuard Connected تنها وضعیت رابط را نشان می‌دهد، نه اینترنت یا handshake. دسترسی کافی روتر لازم است. تونل روی روتر مدیریت می‌شود و برنامه VPN محلی روی گوشی/کامپیوتر ایجاد نمی‌کند.

تصاویر ارائه‌شده مربوط به ویندوز هستند؛ اندروید همین بخش‌های اصلی کنترل را دارد.

<p><img src="docs/screenshots/windows-passwall.png" alt="Passwall ویندوز" width="360"> <img src="docs/screenshots/windows-router-tools.png" alt="ابزارهای روتر در ویندوز" width="360"></p>

## سورس و ساخت

`htdocs/`، `ucode/`، `root/` و `Makefile` شامل رابط، قالب، helperها، سرویس، ACL و مشخصات بسته‌اند. `companion/` سورس و نصب‌کننده ویندوز است؛ `android/` سورس، ساخت، تست و مجوزهای اندروید را دارد. `tests/` تست‌های روتر، `release/raywrt-1.0.0-gale/` ورودی ثابت ساخت و بسته فریز‌شده و `docs/screenshots/` تصاویر را نگه می‌دارند.

در Ubuntu/WSL2 از [راهنمای Gale](BUILD_GALE_1.0.0.md) و [راهنمای لینوکس](release/raywrt-1.0.0-gale/BUILD.md) استفاده کنید. نسخه‌های ثابت OpenWrt/feedها و پروفایل `google_wifi` را حفظ کنید. خروجی `raywrt-1.0.0-gale-sysupgrade.bin` است. قبل از ارتقا بکاپ بگیرید، [بازیابی Gale](release/raywrt-1.0.0-gale/GALE_RECOVERY.md) را بخوانید و متادیتا/SHA256 را بررسی کنید. APهای پیش‌فرض نصب جدید در هر دو باند `RayWRT` هستند؛ SSID سفارشی هنگام ارتقا حفظ می‌شود.

ویندوز از `companion/RayWRT.Companion.csproj` و SDK مشخص‌شده ساخته می‌شود. اندروید [راهنما](android/README.md) و `android/build.ps1` دارد؛ اسکریپت ابزارها را دریافت و کلید امضای محلی ایجاد می‌کند. کلیدها، بکاپ‌ها و کش در Git نیستند. فایل sysupgrade، برنامه portable و نصب‌کننده ویندوز و APK اندروید را از [GitHub Releases](https://github.com/Heygoodbye/RayWRT/releases/tag/v1.0.0) دریافت کنید. checksum کنار فایل‌ها ارائه شده است.

## مجوز و قدردانی

RayWRT تحت [Apache-2.0](LICENSE) است. اجزای دیگر مجوز خود را حفظ می‌کنند؛ مجوز xterm.js و notices اندروید در سورس هستند.

- [OpenWrt](https://github.com/openwrt/openwrt) و [LuCI](https://github.com/openwrt/luci): فریمور، UCI/ubus، مدیریت اصلی و زیرساخت پوسته/بسته.
- [KAJOOSH/iran-ip-database](https://github.com/KAJOOSH/iran-ip-database): فهرست CIDRهای IPv4 مسیریابی‌شده ایران؛ RIPE NCC منبع داده معرفی شده است.
- [Openwrt-Passwall/openwrt-passwall2](https://github.com/Openwrt-Passwall/openwrt-passwall2): مدیر Passwall 2.
- [Openwrt-Passwall/openwrt-passwall-build](https://github.com/Openwrt-Passwall/openwrt-passwall-build): مخزن/ساخت بسته‌های APK.
- [saeed9400/IRAN_Passwall2](https://github.com/saeed9400/IRAN_Passwall2): الهام مسیریابی ایران و مرجع نصب opkg سازگار؛ اسکریپت opkg روی تارگت APK اجرا نمی‌شود.
- [WireGuard](https://www.wireguard.com/)، [Xray-core](https://github.com/XTLS/Xray-core)، [sing-box](https://github.com/SagerNet/sing-box) و [OpenVPN](https://github.com/OpenVPN/openvpn): اجزای اختیاری VPN/پروکسی.
- [ttyd](https://github.com/tsl0922/ttyd) و [xterm.js](https://github.com/xtermjs/xterm.js): انتقال/نمایش ترمینال.
- [SSH.NET](https://github.com/sshnet/SSH.NET): SSH ویندوز؛ [mwiede/JSch](https://github.com/mwiede/jsch) و [Bouncy Castle](https://github.com/bcgit/bc-java): SSH/رمزنگاری اندروید.
- [.NET](https://github.com/dotnet/runtime) و [NSIS](https://nsis.sourceforge.io/): محیط اجرا/نصب‌کننده ویندوز.

از این پروژه‌ها و مشارکت‌کنندگانشان سپاسگزاریم. RayWRT مستقل است و محصول رسمی Google یا پروژه‌های بالادستی نیست.
