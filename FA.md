<div dir="rtl">

> **🧪 <span dir="ltr">RayWRT</span> فقط روی <span dir="ltr">Google WiFi AC-1304 (Gale)</span> با <span dir="ltr">OpenWrt 25.12.5</span> تست شده. روی روترها یا نسخه‌های دیگه هنوز تستش نکردیم.**

# 🟢 <span dir="ltr">RayWRT</span>

[📖 <span dir="ltr">English</span>](english.md) · [<span dir="ltr">GitHub</span>](https://github.com/Heygoodbye/RayWRT)

<span dir="ltr">RayWRT</span> یه تم تیره و سبز برای <span dir="ltr">LuCI</span> داره، با داشبورد زنده و ابزارهایی که مدیریت روتر رو راحت‌تر می‌کنن. برنامه ویندوز و اندروید هم داره تا از گوشی یا کامپیوتر روترت رو کنترل کنی. این پروژه رو [<span dir="ltr">Heygoodbye</span>](https://github.com/Heygoodbye) ساخته و همه اطلاعاتش از خود روتر میاد؛ صفحات اصلی <span dir="ltr">OpenWrt</span> هم همچنان در دسترس هستن.

## 🧪 روی چی تست شده؟

| بخش | نسخه / دستگاه |
| --- | --- |
| روتر | <span dir="ltr">Google WiFi AC-1304 (Gale)</span> |
| <span dir="ltr">OpenWrt</span> | <span dir="ltr">25.12.5 / r33051-f5dae5ece4</span> |
| تارگت و پروفایل | <span dir="ltr">ipq40xx/chromium / google_wifi</span> |
| بسته فریمور | <span dir="ltr">RayWRT 1.0.0</span> |
| برنامه ویندوز | <span dir="ltr">Windows x64</span>، <span dir="ltr">WPF / .NET</span> |
| برنامه اندروید | اندروید ۸ به بالا |

✅ ساخت فریمور، بررسی مشخصات ایمیج، فایل‌های داخلش و <span dir="ltr">checksum</span> با موفقیت انجام شده.

📦 نسخه اول توی <span dir="ltr">GitHub</span> به‌صورت انتشار معمولی منتشر شده. ساخت و بررسی ایمیج موفق بوده؛ تست رسمی نصب تمیز هنوز مونده. شماره نسخه برنامه‌ها جدا از فریموره.

## 📊 داشبورد و ظاهر <span dir="ltr">LuCI</span>

- تم تیره و سبز، کارت‌های گرد و سایه‌دار، با دکمه روشن/خاموش کردن پس‌زمینه تزئینی.
- منوی کناری قابل جمع شدن، جست‌وجوی تنظیمات و زیرمنوی برنامه‌های <span dir="ltr">LuCI</span>.
- ظاهر مناسب موبایل با نوار شناور <span dir="ltr">Home</span>، <span dir="ltr">Tools</span>، <span dir="ltr">Passwall</span>، <span dir="ltr">Terminal</span> و <span dir="ltr">More</span>.
- نمایش زنده <span dir="ltr">CPU</span>، <span dir="ltr">RAM</span>، مدت روشن بودن روتر، کل مصرف اینترنت، نسخه فریمور و کرنل، ساعت، بار سیستم و فضای ذخیره‌سازی.
- وضعیت <span dir="ltr">WAN</span>، آدرس <span dir="ltr">IP</span>، سرعت دانلود و آپلود و نمودار ترافیک اخیر.
- لیست دستگاه‌ها با <span dir="ltr">IP</span>، نوع اتصال، دانلود، آپلود و مصرف روزانه.
- وضعیت <span dir="ltr">Wi-Fi</span> و اسم شبکه‌ها، دسترسی به تنظیمات بی‌سیم، بکاپ، ارتقا و ریبوت.

![داشبورد LuCI](docs/screenshots/dashboard.png)

اسم دستگاه‌ها و تشخیص <span dir="ltr">Wi-Fi</span> یا <span dir="ltr">LAN</span> از اطلاعات <span dir="ltr">DHCP</span> و اتصال‌های شبکه میاد. اگه اطلاعات کافی نباشه، دستگاه <span dir="ltr">Unknown</span> می‌مونه. دما هم فقط وقتی نمایش داده می‌شه که سنسور معتبر <span dir="ltr">CPU</span> یا <span dir="ltr">SoC</span> موجود باشه؛ روی <span dir="ltr">Gale</span> فعلاً دمای معتبر <span dir="ltr">CPU</span> نداریم. وضعیت <span dir="ltr">Connected</span> برای <span dir="ltr">WAN</span> یعنی رابط وصله، نه اینکه اینترنت حتماً کار می‌کنه.

## 🧰 ابزارهای <span dir="ltr">RayWRT</span>

- کارت‌های دسترسی سریع و دسته‌بندی <span dir="ltr">VPN</span>، شبکه، سیستم، عیب‌یابی و ابزارهای پیشرفته.
- تشخیص جداگانه اینکه یه ابزار نصب شده، تنظیم شده یا در حال اجراست.
- تشخیص مدیر بسته و معماری روتر، بررسی مخزن‌ها و فضای خالی و نمایش لاگ نصب.
- نصب و عملیات مسیریابی در پس‌زمینه، همراه با نمایش پیشرفت برای جلوگیری از درخواست‌های طولانی <span dir="ltr">XHR</span>.
- دسترسی به <span dir="ltr">Passwall 2</span>، <span dir="ltr">WireGuard</span>، <span dir="ltr">Xray</span>، <span dir="ltr">sing-box</span>، <span dir="ltr">OpenVPN</span> و <span dir="ltr">ttyd</span>، اگه بسته مناسبشون موجود باشه.
- میان‌بر تنظیمات رابط‌ها، مسیرها، فایروال، <span dir="ltr">Wi-Fi</span>، بسته‌ها، بکاپ، حافظه و لاگ‌ها.
- باز کردن صفحه اصلی مدیریت <span dir="ltr">OpenVPN</span> و پشتیبانی از <span dir="ltr">WireGuard</span> موقع ساخت رابط شبکه.

ابزارهای اختیاری رو خودت هر وقت خواستی نصب می‌کنی. اینکه یه ابزار توی لیست هست، یعنی ازش پشتیبانی می‌کنیم؛ لزوماً از قبل نصب یا روشن نیست. نصب <span dir="ltr">Passwall</span> روی این نسخه از مخزن امضاشده <span dir="ltr">APK</span> استفاده می‌کنه و مشکل تداخل <span dir="ltr">ip-tiny</span> و <span dir="ltr">ip-full</span> رو توی همون عملیات نصب حل می‌کنه<span dir="ltr">. Passwall</span> نصب‌شده حتی اگه خاموش باشه یا هنوز تنظیمش نکرده باشی، <span dir="ltr">Installed</span> نمایش داده می‌شه.

![ابزارهای RayWRT](docs/screenshots/raywrt-tools.png)

![اطلاعات و ابزارهای سیستم](docs/screenshots/system-tools.png)

## 📈 مصرف اینترنت

اینجا می‌تونی کل دانلود و آپلود، مصرف امروز و دیروز، ۷ و ۳۰ روز اخیر، مصرف هر دستگاه و تاریخچه روزانه رو ببینی.

بخش‌های <span dir="ltr">Overview</span>، <span dir="ltr">Devices</span>، <span dir="ltr">History</span>، <span dir="ltr">Diagnostics</span> و <span dir="ltr">Settings</span> هم برای دیدن آمار و تنظیماتش هستن. می‌تونی مدت نگهداری آمار و فاصله ذخیره‌سازی رو تنظیم کنی یا با تأیید خودت تاریخچه رو پاک کنی. شمارنده‌های زنده توی <span dir="ltr">RAM</span> می‌مونن و مجموع روزانه هر چند وقت یک‌بار ذخیره می‌شه.

این عددها ترافیکیه که <span dir="ltr">RayWRT</span> ثبت کرده؛ ممکنه با صورتحساب شرکت اینترنت یکی نباشن. مجموع <span dir="ltr">WAN</span> و دستگاه‌ها هم به خاطر ترافیک خود روتر و نحوه تشخیص دستگاه‌ها می‌تونه فرق داشته باشه.

![مصرف اینترنت](docs/screenshots/data-usage.png)

## 🇮🇷 <span dir="ltr">WireGuard</span> و <span dir="ltr">Iran Direct</span>

با <span dir="ltr">Iran Direct</span>، ترافیک **<span dir="ltr">IPv4</span> ایران** از اینترنت معمولی <span dir="ltr">WAN</span> می‌ره و بقیه ترافیک <span dir="ltr">IPv4</span> از مسیر پیش‌فرض <span dir="ltr">WireGuard</span> انتخاب‌شده عبور می‌کنه.

می‌تونی تونل و <span dir="ltr">WAN</span> رو جدا انتخاب کنی، لیست <span dir="ltr">IP</span>های ایران رو آپدیت کنی و تعداد محدوده‌ها، زمان آخرین آپدیت و وضعیت مسیر رو ببینی. لیست دانلودشده قبل از استفاده بررسی می‌شه و وقتی قابلیت روشنه، به‌صورت دوره‌ای هم آپدیت می‌شه. این بخش جدول <span dir="ltr">nftables</span> و مسیریابی خودش رو داره و مستقل از <span dir="ltr">Passwall</span> کار می‌کنه.

وقتی <span dir="ltr">Enable</span> رو می‌زنی، رابط <span dir="ltr">full-tunnel</span> انتخاب‌شده و مسیر پیش‌فرضش آماده می‌شن. اگه بررسی مسیر موفق نباشه، تغییراتی که موقع فعال‌سازی انجام شده برمی‌گردن<span dir="ltr">. Disable</span> یا حذف رابط انتخاب‌شده هم قوانین <span dir="ltr">RayWRT</span> رو پاک می‌کنه.

این قابلیت فقط برای <span dir="ltr">IPv4</span>ه و <span dir="ltr">IPv6</span> رو تغییر نمی‌ده. یه <span dir="ltr">peer</span> معتبر با <code dir="ltr">0.0.0.0/0</code>، سرور قابل دسترس و تنظیم درست فایروال لازمه. روشن بودن رابط یا وجود مسیر به‌تنهایی تأیید نمی‌کنه که <span dir="ltr">handshake</span> موفق بوده؛ وضعیت <span dir="ltr">handshake</span> رو باید جدا بررسی کنی. هیچ کلید، آدرس سرور یا کانفیگ شخصی <span dir="ltr">Meli</span> داخل فریمور نیست.

![مسیریابی مستقیم ایران](docs/screenshots/wireguard-iran-routing.png)

## 💻 ترمینال داخل پنل

ترمینال <span dir="ltr">root</span> با <span dir="ltr">ttyd</span> و <span dir="ltr">xterm.js</span> داخل خود <span dir="ltr">LuCI</span> باز می‌شه. دکمه‌های <span dir="ltr">Connect</span> و <span dir="ltr">Disconnect/Stop</span>، نمایش وضعیت و چیدمان مناسب موبایل داره. دسترسی از نشست <span dir="ltr">LuCI/RayWRT</span> و ابزار مدیریت ترمینال انجام می‌شه. بعد از کارت ترمینال رو <span dir="ltr">Stop</span> کن؛ این بخش دسترسی کامل مدیریتی به روتر داره.

## 🎮 تست پینگ و عیب‌یابی

تست‌ها هم‌زمان از خود روتر برای سایت <span dir="ltr">OpenWrt</span> و سرورهای اروپایی این بازی‌ها اجرا می‌شن:

- <span dir="ltr">World of Warcraft</span>
- <span dir="ltr">League of Legends EUW / EUNE</span>
- <span dir="ltr">Escape from Tarkov</span>
- <span dir="ltr">World of Tanks</span>
- <span dir="ltr">Fortnite</span> در آلمان، فرانسه و بریتانیا
- <span dir="ltr">PUBG</span>

نتیجه‌ها پینگ، <span dir="ltr">packet loss</span>، تعداد پاسخ‌ها و میانگین و بازه پینگ سرورهای هر بازی رو نشون می‌دن. موقع اجرای دوباره، نتیجه قبلی می‌مونه و <span dir="ltr">Testing</span> نمایش داده می‌شه<span dir="ltr">. IP</span> خام سرورهای بازی هم نمایش داده نمی‌شه و به جاش اسم یا شماره سرور رو می‌بینی. این تست <span dir="ltr">ICMP</span>ه و تضمین نمی‌کنه پینگ داخل بازی دقیقاً همین باشه.

![تست پینگ بازی‌ها](docs/screenshots/gaming-diagnostics.png)

## 📱 برنامه ویندوز و اندروید

| بخش | کارهایی که می‌تونی انجام بدی |
| --- | --- |
| 🔌 اتصال روتر | ورود با <span dir="ltr">SSH</span>، دیدن وضعیت اتصال، <span dir="ltr">Refresh</span> و تأیید <span dir="ltr">fingerprint</span> روتر؛ رمز ورود ذخیره نمی‌شه. |
| 🌐 <span dir="ltr">Passwall 2</span> | روشن/خاموش، عوض کردن نود، اضافه کردن لینک نود یا سابسکریپشن، آپدیت دستی سابسکریپشن‌ها، حذف کانفیگ‌هایی که امکان حذفشون هست و باز کردن <span dir="ltr">LuCI</span>. |
| 🛡️ <span dir="ltr">WireGuard</span> | دیدن، وصل و قطع کردن تونل‌ها؛ وارد کردن فایل <code dir="ltr">.conf</code> یا متن کانفیگ؛ اضافه کردن رابط واردشده به <span dir="ltr">zone</span> فایروال <span dir="ltr">WAN</span> و هماهنگ کردن تونل انتخاب‌شده با <span dir="ltr">Iran Direct</span>. |
| 🧰 ابزارهای روتر | تست ۱۵ مقصد تنظیم‌شده، مدیریت <span dir="ltr">Wi-Fi</span> در باندهای ۲٫۴ و ۵ گیگاهرتز، تغییر اسم شبکه و رمز و ریبوت با تأیید. |
| 🎨 ظاهر | پنل‌های تیره و مناسب اندازه صفحه، بررسی دوره‌ای اتصال و لینک سازنده؛ ویندوز پنجره بدون حاشیه و قابل جابه‌جایی، نسخه <span dir="ltr">portable</span> و نصب‌کننده داره. |

هر دو برنامه اطلاعات واقعی <span dir="ltr">UCI</span> و <span dir="ltr">ubus</span> رو با <span dir="ltr">SSH</span> از روتر می‌گیرن. مجموعه ۱۵ مقصد شامل سایت <span dir="ltr">OpenWrt</span> و سرورهای بازی اروپاست<span dir="ltr">. SSH Connected</span> یعنی اتصال <span dir="ltr">SSH</span> برقرار شده و <span dir="ltr">WireGuard Connected</span> یعنی رابط فعاله؛ هیچ‌کدوم به‌تنهایی اینترنت یا <span dir="ltr">handshake</span> رو تأیید نمی‌کنن.

برای استفاده، <span dir="ltr">SSH</span> و دسترسی کافی روی روتر لازمه. برنامه تونل رو روی روتر مدیریت می‌کنه و روی خود گوشی یا کامپیوتر <span dir="ltr">VPN</span> ایجاد نمی‌کنه.

عکس‌های زیر از برنامه ویندوز هستن؛ برنامه اندروید هم همین بخش‌های اصلی رو داره.

<p><img src="docs/screenshots/windows-passwall.png" alt="Passwall ویندوز" width="360"> <img src="docs/screenshots/windows-router-tools.png" alt="ابزارهای روتر در ویندوز" width="360"></p>

## 🔧 سورس و ساخت پروژه

| مسیر | چی داخلشه؟ |
| --- | --- |
| <code dir="ltr">htdocs/</code>، <code dir="ltr">ucode/</code>، <code dir="ltr">root/</code> و <code dir="ltr">Makefile</code> | رابط و قالب‌ها، <span dir="ltr">helper</span>ها، سرویس‌ها، <span dir="ltr">ACL</span> و مشخصات بسته |
| <code dir="ltr">companion/</code> | سورس برنامه ویندوز و نصب‌کننده |
| <code dir="ltr">android/</code> | سورس اندروید، اسکریپت ساخت، تست‌ها و مجوز کتابخانه‌ها |
| <code dir="ltr">tests/</code> | تست‌های مربوط به روتر |
| <code dir="ltr">release/raywrt-1.0.0-gale/</code> | ورودی‌های ثابت ساخت و سورس فریز‌شده بسته |
| <code dir="ltr">docs/screenshots/</code> | اسکرین‌شات‌ها |

برای ساخت فریمور روی <span dir="ltr">Ubuntu</span> یا <span dir="ltr">WSL2</span>، [راهنمای <span dir="ltr">Gale</span>](BUILD_GALE_1.0.0.md) و [راهنمای لینوکس](release/raywrt-1.0.0-gale/BUILD.md) رو دنبال کن. نسخه‌های مشخص‌شده <span dir="ltr">OpenWrt</span> و <span dir="ltr">feed</span>ها و پروفایل <code dir="ltr">google_wifi</code> رو تغییر نده. اسم خروجی <code dir="ltr">raywrt-1.0.0-gale-sysupgrade.bin</code> است.

قبل از ارتقا بکاپ بگیر، [راهنمای بازیابی <span dir="ltr">Gale</span>](release/raywrt-1.0.0-gale/GALE_RECOVERY.md) رو بخون و متادیتا و <span dir="ltr">SHA256</span> رو چک کن. در نصب جدید اسم شبکه‌های پیش‌فرض هر دو باند <code dir="ltr">RayWRT</code> می‌شه؛ اسم شبکه‌ای که خودت تنظیم کرده باشی موقع ارتقا حفظ می‌شه.

ویندوز از <code dir="ltr">companion/RayWRT.Companion.csproj</code> با <span dir="ltr">SDK</span> مشخص‌شده ساخته می‌شه. برای اندروید هم [راهنما](android/README.md) و <code dir="ltr">android/build.ps1</code> رو ببین؛ اسکریپت ابزارها رو می‌گیره و یه کلید امضای محلی می‌سازه. کلیدها، بکاپ‌ها و کش ساخت وارد <span dir="ltr">Git</span> نمی‌شن.

📥 فایل <span dir="ltr">sysupgrade</span>، نصب‌کننده ویندوز و <span dir="ltr">APK</span> یونیورسال اندروید توی [<span dir="ltr">GitHub Releases</span>](https://github.com/Heygoodbye/RayWRT/releases/tag/v1.0.0) هستن. هش <span dir="ltr">SHA256</span> هر فایل هم توی توضیحات انتشار هست.

## 🙏 مجوز و تشکر از پروژه‌های دیگه

سورس <span dir="ltr">RayWRT</span> با مجوز [<span dir="ltr">Apache-2.0</span>](LICENSE) منتشر شده. کتابخانه‌های دیگه مجوز خودشون رو دارن؛ فایل مجوز <span dir="ltr">xterm.js</span> و <span dir="ltr">notices</span> اندروید هم داخل سورس هستن.

- [<span dir="ltr">OpenWrt</span>](https://github.com/openwrt/openwrt) و [<span dir="ltr">LuCI</span>](https://github.com/openwrt/luci): فریمور، <span dir="ltr">UCI/ubus</span>، مدیریت اصلی روتر و زیرساخت تم و بسته‌ها.
- [<span dir="ltr">farshidmousavii/iran-ip-ranges</span>](https://github.com/farshidmousavii/iran-ip-ranges): لیست <span dir="ltr">IPv4</span> ایران با مجوز <span dir="ltr">MIT</span>.
- [<span dir="ltr">Openwrt-Passwall/openwrt-passwall2</span>](https://github.com/Openwrt-Passwall/openwrt-passwall2): برنامه <span dir="ltr">Passwall 2</span>.
- [<span dir="ltr">Openwrt-Passwall/openwrt-passwall-build</span>](https://github.com/Openwrt-Passwall/openwrt-passwall-build): ساخت و مخزن بسته‌های <span dir="ltr">APK</span>.
- [<span dir="ltr">saeed9400/IRAN_Passwall2</span>](https://github.com/saeed9400/IRAN_Passwall2): ایده مسیریابی ایران و مرجع نصب برای فریمورهای سازگار با <span dir="ltr">opkg</span>؛ اسکریپت <span dir="ltr">opkg</span> روی نسخه <span dir="ltr">APK</span> فعلی اجرا نمی‌شه.
- [<span dir="ltr">WireGuard</span>](https://www.wireguard.com/)، [<span dir="ltr">Xray-core</span>](https://github.com/XTLS/Xray-core)، [<span dir="ltr">sing-box</span>](https://github.com/SagerNet/sing-box) و [<span dir="ltr">OpenVPN</span>](https://github.com/OpenVPN/openvpn): بخش‌های اختیاری <span dir="ltr">VPN</span> و پروکسی.
- [<span dir="ltr">ttyd</span>](https://github.com/tsl0922/ttyd) و [<span dir="ltr">xterm.js</span>](https://github.com/xtermjs/xterm.js): اتصال و نمایش ترمینال.
- [<span dir="ltr">SSH.NET</span>](https://github.com/sshnet/SSH.NET): <span dir="ltr">SSH</span> ویندوز؛ [<span dir="ltr">mwiede/JSch</span>](https://github.com/mwiede/jsch) و [<span dir="ltr">Bouncy Castle</span>](https://github.com/bcgit/bc-java): <span dir="ltr">SSH</span> و رمزنگاری اندروید.
- [<span dir="ltr">.NET</span>](https://github.com/dotnet/runtime) و [<span dir="ltr">NSIS</span>](https://nsis.sourceforge.io/): محیط اجرا و نصب‌کننده ویندوز.

ممنون از سازنده‌ها و همه کسایی که توی این پروژه‌ها کمک کردن 💚 <span dir="ltr">RayWRT</span> یه پروژه مستقله و محصول رسمی <span dir="ltr">Google</span> یا پروژه‌های بالا نیست.

</div>
