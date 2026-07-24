# یادیار (Yadyar)

اپلیکیشن «سازمان‌دهنده شخصی» برای کاربران ایرانی — یادداشت/یادآور، مدیریت اشتراک و قبض، و لیست خرید خانواده.
این اپ کاملاً **آفلاین** کار می‌کند: بدون سرور، بدون API خارجی، بدون هزینه نگهداری. تمام داده‌ها به‌صورت محلی روی دستگاه کاربر (SQLite) ذخیره می‌شوند.

## پشته فناوری (Tech Stack)

| هدف | پکیج |
| --- | --- |
| پایگاه‌داده محلی | `sqflite` |
| مسیرهای فایل سیستم | `path_provider` |
| ذخیره‌سازی ساده کلید-مقدار | `shared_preferences` |
| اعلان‌های محلی (یادآورها) | `flutter_local_notifications` + `timezone` |
| مدیریت state | `provider` |
| نمودار و آمار | `fl_chart` |
| فرمت اعداد/تاریخ | `intl` |
| تقویم شمسی | `shamsi_date` |

## ساختار پروژه

```
lib/
├── main.dart              # نقطه ورود اپ + اسکلت ناوبری ۴ تب
├── constants/              # مقادیر ثابت (نام اپ، رنگ‌ها و ...)
│   └── app_constants.dart
├── models/                 # Note, Reminder, Subscription, ShoppingList, ShoppingItem
├── database/               # DatabaseHelper: راه‌اندازی، جدول‌ها و مهاجرت (migration) sqflite
├── repositories/           # NoteRepository, ReminderRepository, SubscriptionRepository, ShoppingListRepository
├── providers/              # مدیریت state با Provider (ChangeNotifier)
├── screens/                # صفحات اصلی اپ
│   ├── notes/              # صفحات مربوط به یادداشت/یادآور
│   ├── bills/               # صفحات مربوط به اشتراک و قبض
│   └── shopping/            # صفحات مربوط به لیست خرید خانواده
├── widgets/                # ویجت‌های قابل استفاده مجدد و مشترک بین صفحات
├── theme/                  # تعریف ThemeData، رنگ‌ها و تایپوگرافی
└── utils/                  # توابع کمکی (تبدیل تاریخ شمسی، فرمت‌دهی و ...)
```

## اجرای پروژه

```bash
flutter pub get
flutter run
```

## وضعیت فعلی

- راه‌اندازی اولیه پروژه و اسکلت ناوبری (۴ تب: داشبورد، یادداشت، قبض‌ها، خرید) ✅
- مدل‌های داده، DatabaseHelper (۵ جدول با روابط FK) و Repository های CRUD کامل ✅
- صفحات و منطق هر بخش (UI) در مراحل بعدی پیاده‌سازی می‌شوند.

تست‌های واحد پایگاه‌داده در [test/database/database_test.dart](test/database/database_test.dart) با `sqflite_common_ffi` روی هر جدول insert/retrieve را پوشش می‌دهند:

```bash
flutter test
```
