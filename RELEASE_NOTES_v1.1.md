# RayWRT v1.1

## English

Tested only on Google WiFi AC-1304 (Gale), OpenWrt 25.12.5. Firmware package: 1.1.0; companion apps: v1.1.

### Firmware fixes
- Fixed Total Used on first boot and after upgrades when accounting files have not yet been created. Preserved historical totals are counted without counting today twice.
- Fixed the blank Internet chart: real SVG rendering now displays green download and purple upload lines with subtle glass-style fills.
- Reduced dashboard overhead by fetching summary totals and current device counters instead of unused history. Original fast refresh is retained: CPU/Internet every second and memory every four seconds.
- Added upgrade backup entries for the Iran IPv4 database and traffic accounting files. Upgrading from older firmware that lacks these entries may require downloading the Iran list again.
- Fixed fresh-install DNS application and verification; existing custom DNS and Wi-Fi settings are preserved.

- Fixed package installation when cached indexes temporarily omit a package: refresh once and retry, with separate refresh-failure and missing-package messages.

### Windows / Android apps
- Firmware verification before enabling controls: stock OpenWrt and theme-only installs are blocked.
- Detection supports different RayWRT builds without requiring identical file hashes.
- Wi-Fi settings apply WPA2-PSK/WPA3-SAE mixed mode with a valid password.
- Windows: safer cleanup during connections/commands and handling of malformed wireless status.
- Android: safer background tasks/callbacks, connection cancellation and limits on oversized SSH responses.
- App footer and installer show v1.1; Android supports updating the final v1 installation.

### Install
Download the Gale sysupgrade from this release, then use LuCI → System → Backup / Flash Firmware. Back up settings first and confirm the device and SHA256 before flashing. Windows: run the supplied Setup.exe. Android 8+: install the universal APK. No personal WireGuard configuration or keys are included.

Build/image verification and actual device acceptance are separate. Clean-sysupgrade acceptance for this new image remains pending; publishing does not certify it on other hardware.

---

<div dir="rtl" align="right">

## فارسی

این نسخه فقط روی Google WiFi AC-1304 (Gale) با OpenWrt 25.12.5 تست شده. نسخهٔ فریمور 1.1.0 و نسخهٔ اپ‌ها v1.1 است.

### تغییرات و رفع باگ‌های فریمور

- مشکل نمایش Total Used بعد از نصب یا ارتقا، وقتی فایل آمار هنوز ساخته نشده، رفع شد. آمار قبلی حفظ می‌شود و مصرف امروز دوبار حساب نمی‌شود.
- نمودار خالی اینترنت درست شد؛ دانلود سبز و آپلود بنفش با پس‌زمینهٔ شیشه‌ای کم‌رنگ نمایش داده می‌شوند.
- داشبورد دیگر تاریخچه‌ای که نیاز ندارد را مرتب دریافت نمی‌کند. سرعت رفرش مثل قبل است: پردازنده و اینترنت هر ثانیه، حافظه هر چهار ثانیه.
- فایل لیست IP ایران و آمار مصرف به بکاپ ارتقا اضافه شدند. اگر از نسخه‌ای قدیمی می‌آیید که این تغییر را ندارد، ممکن است لازم باشد لیست ایران را دوباره آپدیت کنید.
- اعمال و بررسی DNS نصب تازه اصلاح شد؛ DNS و تنظیمات وای‌فای شخصی شما حفظ می‌شوند.

- اگر لیست کش‌شدهٔ بسته‌ها قدیمی باشد، نصب‌کننده یک بار آن را تازه می‌کند و دوباره بررسی می‌کند؛ خطای اینترنت و نبودن واقعی بسته جدا نمایش داده می‌شوند.

### تغییرات اپ ویندوز و اندروید

- قبل از فعال شدن دکمه‌ها، فریمور RayWRT بررسی می‌شود؛ OpenWrt معمولی و نصبِ فقط تم پشتیبانی نمی‌شوند.
- تشخیص نسخه‌های مختلف RayWRT بهتر شده و دیگر به یکسان بودن هش همهٔ فایل‌ها وابسته نیست.
- ذخیرهٔ وای‌فای با رمز معتبر، حالت ترکیبی WPA2/WPA3 را اعمال می‌کند.
- ویندوز: بستن برنامه هنگام اتصال یا اجرای دستور امن‌تر شده و دادهٔ خراب وضعیت وای‌فای بهتر مدیریت می‌شود.
- اندروید: کارهای پس‌زمینه و لغو اتصال بهتر مدیریت می‌شوند و حجم پاسخ SSH محدود شده است.
- نسخهٔ نمایش‌داده‌شده در اپ و نصب‌کننده v1.1 است. اپ اندروید روی نسخهٔ نهایی v1 آپدیت می‌شود.

### نصب

فایل sysupgrade مخصوص Gale را از همین Release بگیرید و در LuCI از بخش System → Backup / Flash Firmware نصب کنید. قبلش بکاپ بگیرید و مدل دستگاه و SHA256 را بررسی کنید. برای ویندوز فایل Setup.exe و برای اندروید ۸ به بالا APK یونیورسال را نصب کنید. کانفیگ یا کلید شخصی WireGuard داخل فریمور نیست.

بررسی فایل بیلد با تست واقعی نصب تمیز فرق دارد. تست نهایی نصب تمیز این تصویر هنوز انجام نشده و دستگاه‌های دیگر تأیید نشده‌اند.

</div>

## Verification / بررسی فایل‌ها

Build, metadata and extracted-image checks passed. Clean-sysupgrade acceptance remains pending. / بررسی بیلد، متادیتا و فایل‌های داخل ایمیج موفق بود؛ تست نهایی نصب تمیز هنوز انجام نشده.

### SHA256

```text
c24fd28e88ebc0ff6acfc80df8ef3f3266c9d88fc4eb1c8f31ea767038f3d1f7  raywrt-1.1.0-gale-sysupgrade.bin
cb072be9e59d85fc89e484d79820f89ebc41db01315a7ed91afeb410b021ed8e  RayWRT-v1.1-Windows-x64-Setup.exe
e40ce68c5371321af9b301408f00ab15fb1262b87a0c2f18db0870c4791057bd  RayWRT-v1.1-Android-universal.apk
```
