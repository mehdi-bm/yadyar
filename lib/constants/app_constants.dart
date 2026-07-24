import 'package:flutter/material.dart';

/// Application-wide constant values (name, colors, shared config).
class AppConstants {
  AppConstants._();

  static const String appName = 'یادیار';
  static const String appNameEn = 'Yadyar';

  static const Color primaryColor = Color(0xFF00695C);
  static const Color secondaryColor = Color(0xFFFFA000);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
  static const Color backgroundColor = Color(0xFFF5F5F5);

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

  static const List<String> shoppingItemCategories = [
    'میوه و سبزیجات',
    'لبنیات',
    'گوشت و پروتئین',
    'نان و غلات',
    'بهداشتی',
    'خانه',
    'نوشیدنی',
    'سایر',
  ];
}
