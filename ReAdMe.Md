```markdown
<div align="center">

<img src="https://img.shields.io/badge/HelloWorld-Panel-8B5CF6?style=for-the-badge&logo=fastapi&logoColor=white" alt="HelloWorld-Panel" />

# 🌍 HelloWorld-Panel

**یک سرویس سبک، سریع و مخفی برای عبور از فیلترینگ**
<br/>
ساخته‌شده با FastAPI · اجرا روی Railway · بدون پنل وب · بدون ردپا

<br/>

[![FastAPI](https://img.shields.io/badge/FastAPI-0.104.1-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org/)
[![Railway](https://img.shields.io/badge/Deploy-Railway-0B0D0E?style=flat-square&logo=railway&logoColor=white)](https://railway.app/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![VLESS](https://img.shields.io/badge/Protocol-VLESS%2FWS-8B5CF6?style=flat-square)](https://xtls.github.io/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

</div>

---

## ✨ چرا HelloWorld-Panel؟

<table>
<tr>
<td width="50%">

### 🚀 فوق‌العاده سبک
بدون دیتابیس، بدون Redis، بدون وابستگی سنگین. فقط FastAPI و یک تونل WebSocket. مصرف رم زیر ۵۰ مگابایت.

### 🕵️ کاملاً مخفی
هیچ پنل مدیریتی، هیچ صفحه لاگین، هیچ `/dashboard` وجود ندارد. فقط یک API ساده که از بیرون شبیه یک وب‌سرویس معمولی است.

### 🔐 پروتکل VLESS/WS
مبتنی بر استاندارد VLESS روی WebSocket با TLS کامل. سازگار با تمام کلاینت‌های مدرن.

</td>
<td width="50%">

### 🎭 ضد DPI
پشتیبانی از **SNI جعلی**، **FinalMask** و **Cipher Suite سفارشی** برای دور زدن سیستم‌های فیلترینگ هوشمند.

### 🌐 مدیریت از GitHub Pages
یک صفحه استاتیک که لیست SNIها را لود می‌کند و کانفیگ دلخواه شما را می‌سازد. بدون نیاز به هیچ بک‌اند اضافه.

### 🐳 دیپلوی تک‌فایلی
فقط یک `Dockerfile`. تمام سورس‌کد، SNIها و وابستگی‌ها داخلش هستن. کافیه همون یک فایل رو آپلود کنی.

</td>
</tr>
</table>

---

## 🎯 ویژگی‌ها در یک نگاه

<div align="center">

| ویژگی | وضعیت | توضیح |
|:------|:-----:|:------|
| پشتیبانی از VLESS/WS | ✅ | استاندارد و پایدار |
| TLS خودکار | ✅ | توسط Railway |
| SNI جعلی قابل تنظیم | ✅ | از طریق متغیر محیطی |
| لینک PattNG | ✅ | با `fp=unsafe` + `finalMask` |
| Cipher Suite سفارشی | ✅ | قابل تنظیم در لینک PattNG |
| حالت تک‌کاربره | ✅ | یک UUID ثابت و بی‌نهایت |
| مدیریت از GitHub Pages | ✅ | صفحه استاتیک |
| بدون پنل وب | ✅ | سطح حمله صفر |
| بدون ربات تلگرام | ✅ | بدون تماس خارجی |
| محدودیت سرعت (اختیاری) | ✅ | Token Bucket |
| محدودیت IP (اختیاری) | ✅ | بر اساس UUID |

</div>

---

## 🛠️ تکنولوژی‌های استفاده‌شده

<div align="center">

<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/python/python-original.svg" width="48" height="48" alt="Python" title="Python 3.11" />
&nbsp;&nbsp;
<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/fastapi/fastapi-original.svg" width="48" height="48" alt="FastAPI" title="FastAPI" />
&nbsp;&nbsp;
<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/docker/docker-original.svg" width="48" height="48" alt="Docker" title="Docker" />
&nbsp;&nbsp;
<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/html5/html5-original.svg" width="48" height="48" alt="HTML5" title="HTML5" />
&nbsp;&nbsp;
<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/javascript/javascript-original.svg" width="48" height="48" alt="JavaScript" title="JavaScript" />
&nbsp;&nbsp;
<img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/github/github-original.svg" width="48" height="48" alt="GitHub" title="GitHub" />

</div>

---

## 🚀 دیپلوی در ۳ دقیقه

### ۱. آپلود فایل
فقط فایل `Dockerfile` رو توی ریپازیتوری گیت‌هابت آپلود کن.

### ۲. اتصال به Railway
```

railway.app → New Project → Deploy from GitHub Repo → انتخاب ریپازیتوری

```

### ۳. تنظیمات ضروری

> ⚠️ **حتماً یک Volume به مسیر `/data` متصل کن!**
> بدون Volume، با هر ری‌استارت UUID عوض می‌شه و کانفیگ قبلی باطل می‌شه.

**متغیرهای محیطی اختیاری:**

| متغیر | توضیح | مثال |
|:------|:------|:------|
| `SECRET_KEY` | کلید ثابت برای تولید UUID | `openssl rand -hex 32` |
| `FAKE_SNI` | SNI جعلی برای دور زدن DPI | `www.microsoft.com` |
| `CIPHER_SUITES` | لیست Cipher Suite سفارشی | `TLS_ECDHE_...:TLS_RSA_...` |

### ۴. گرفتن کانفیگ

بعد از دیپلوی موفق، در **Deploy Logs** به دنبال این بگرد:

```

══════════════════════════════════════════════════════════════════════
Standard link (v2rayNG / v2rayN):
vless://xxxx@your-app.up.railway.app:443?...
──────────────────────────────────────────────────────────────────────
PattNG link (fp=unsafe + finalMask + cipher suites):
vless://xxxx@your-app.up.railway.app:443?...
──────────────────────────────────────────────────────────────────────
══════════════════════════════════════════════════════════════════════

```

لینک رو کپی کن و توی کلاینتت ایمپورت کن. تمام. ✅

---

## 🎨 SNI سفارشی از GitHub Pages

پروژه یک صفحه استاتیک داره که بهت اجازه می‌ده با انتخاب هر SNI از لیست، کانفیگ سفارشی بسازی.

<div align="center">

### 🌐 [**دسترسی به صفحه**](https://AghaBanafshi-2.github.io/HelloWorld-Panel/)

</div>

**نحوه استفاده:**

1. برو به صفحه GitHub Pages
2. آدرس Railway خودت رو وارد کن و **ذخیره** بزن
3. از لیست، یک SNI انتخاب کن (بیش از ۷۰ دامنه ایرانی و بین‌المللی)
4. روی **دریافت کانفیگ** کلیک کن
5. لینک Standard یا PattNG رو کپی کن

> 💡 لیست SNIها توی فایل `sni.txt` هست و می‌تونی هر وقت خواستی ویرایشش کنی (فقط push کن، نیازی به دیپلوی مجدد Railway نیست).

---

## 📡 API Reference

<div align="center">

| متد | مسیر | توضیح |
|:---:|:-----|:------|
| `GET` | `/` | بررسی سلامت سرویس |
| `GET` | `/health` | جزئیات اتصالات + آپتایم |
| `GET` | `/ws/{uuid}` | تونل WebSocket (VLESS) |
| `GET` | `/sub/{uuid}` | لینک سابسکریپشن Base64 |
| `GET` | `/get/config?sni=X` | ساخت کانفیگ با SNI دلخواه |

</div>

**نمونه خروجی `/get/config`:**

```json
{
  "standard": "vless://uuid@host:443?encryption=none&...&sni=varzesh3.com&fp=chrome",
  "patt": "vless://uuid@host:443?...&fp=unsafe&fm=tlshello&cs=...",
  "sni": "varzesh3.com",
  "uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "host": "your-app.up.railway.app"
}
```

---

🛡️ چرا ضد فیلتره؟

<div align="center">

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   DPI (Deep Packet Inspection)                              │
│           │                                                 │
│           ├──❌ می‌بینه /dashboard و پنل رو → بلاک            │
│           ├──❌ می‌بینه api.telegram.org → بلاک              │
│           ├──❌ می‌بینه الگوی پنل شناخته‌شده → بلاک           │
│           │                                                 │
│           └──✅ HelloWorld-Panel:                           │
│                  • / فقط یه {"status":"ok"} برمی‌گردونه       │
│                  • هیچ پنلی وجود نداره                      │
│                  • هیچ تماس خارجی نداره                     │
│                  • SNI دلخواه → ترافیک عادی به نظر می‌رسه    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

</div>

تکنیک‌های استفاده‌شده

تکنیک توضیح
🎭 SNI Spoofing ارسال SNI جعلی در TLS handshake
🔪 FinalMask (Fragment) شکستن ClientHello به تکه‌های کوچک
🔐 Custom Cipher Suites استفاده از Cipher Suiteهای قدیمی/نامعمول
🕵️ Zero Fingerprint هیچ امضای نرم‌افزاری در پاسخ‌ها نیست
🚫 No Panel سطح حمله صفر برای اسکنرها

---

📱 کلاینت‌های پیشنهادی

<div align="center">

کلاینت پلتفرم مناسب برای
v2rayNG Android لینک Standard
v2rayN Windows لینک Standard
PattNG Android لینک PattNG (بهترین نتیجه)
NekoBox Android هر دو لینک
Streisand iOS/Mac لینک Standard

</div>

---

📝 نکات مهم

[!IMPORTANT]
حتماً Volume به /data متصل کن. بدون این کار، هر ری‌استارت UUID جدید می‌سازه و کانفیگ قبلی باطل می‌شه.

[!TIP]
اگه می‌خوای DPI رو مؤثرتر دور بزنی، از لینک PattNG با کلاینت PattNG استفاده کن. اون کلاینت fp=unsafe و finalMask رو کاملاً پشتیبانی می‌کنه.

[!WARNING]
از دامنه‌های *.up.railway.app گاهی به‌عنوان نشانه شناسایی استفاده می‌شه. اگه می‌تونی، یک دامنه سفارشی ارزون (مثل .xyz) بگیر و به Railway وصل کن.

[!NOTE]
این پروژه عمداً هیچ پنل مدیریتی و ربات تلگرامی نداره. اگه بعداً خواستی کاربر اضافه کنی، باید کد رو تغییر بدی و دیپلوی مجدد کنی.

---

🤝 مشارکت

از هر نوع مشارکت استقبال می‌شه!


# Fork
# Clone
```git clone https://github.com/AghaBanafshi-2/HelloWorld-Panel.git```

# Branch
git checkout -b feature/amazing

# Commit
git commit -m "feat: add amazing feature"

# Push
git push origin feature/amazing
```

بعدش یه Pull Request باز کن. 🙌

---

📄 لایسنس

<div align="center">

MIT License · با ❤️ برای اینترنت آزاد

<br/>

<a href="https://github.com/AghaBanafshi-2/HelloWorld-Panel">
<img src="https://img.shields.io/badge/Made%20with-%E2%9D%A4%EF%B8%8F-8B5CF6?style=for-the-badge" alt="Made with Love" />
</a>





⭐ اگه این پروژه بهت کمک کرد، یه ستاره بده! ⭐

<br/>

<a href="https://github.com/AghaBanafshi-2/HelloWorld-Panel/stargazers">
<img src="https://img.shields.io/github/stars/AghaBanafshi-2/HelloWorld-Panel?style=social" alt="Stars" />
</a>

</div>

---

<div align="center">

🌐 دیگر پروژه‌ها

<a href="https://github.com/AghaBanafshi-2">
<img src="https://img.shields.io/badge/GitHub-AghaBanafshi--2-181717?style=for-the-badge&logo=github" alt="GitHub" />
</a>





<sub>ساخته‌شده با ☕ و بی‌خوابی</sub>

</div>
