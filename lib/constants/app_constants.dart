/// Application-wide constant values (name, colors, shared config).
class AppConstants {
  AppConstants._();

  static const String appName = 'یادیار پارسیک';
  static const String appNameEn = 'Yadyar';

  static const List<String> subscriptionCategories = [
    'اینترنت',
    'برق',
    'آب',
    'گاز',
    'تلفن همراه',
    'اشتراک نرم‌افزار',
    'بیمه',
    'اجاره',
    'سایر',
  ];

  // دسته‌بندی‌های خرید دیگر ثابت نیستند و در پایگاه‌داده مدیریت می‌شوند؛
  // مقادیر اولیه در ShoppingCategory.defaults است.

  static const List<String> shoppingUnits = [
    'عدد',
    'کیلوگرم',
    'گرم',
    'لیتر',
    'بسته',
    'جعبه',
    'شانه',
    'بطری',
    'قوطی',
    'متر',
  ];
}
