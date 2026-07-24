import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';
import '../models/subscription.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _permissionRequestedKey = 'notification_permission_requested';
  static const _subscriptionIdOffset = 1000000000;
  static const _channelId = 'yadyar_reminders';
  static const _channelName = 'یادآورهای یادیار';
  static const _channelDescription = 'یادآوری یادداشت‌ها، اشتراک‌ها و قبض‌ها';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;

    tz_data.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } on Object {
      // DateTime.now().timeZoneOffset keeps scheduling useful on an unusual
      // device timezone that is not present in the bundled timezone database.
      final offset = DateTime.now().timeZoneOffset;
      final fallback = offset == const Duration(hours: 3, minutes: 30)
          ? 'Asia/Tehran'
          : 'UTC';
      tz.setLocalLocation(tz.getLocation(fallback));
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _notifications.initialize(settings: settings);
    _isInitialized = true;
  }

  Future<void> requestPermissionOnFirstLaunch() async {
    if (!_isInitialized || kIsWeb) return;

    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_permissionRequestedKey) ?? false) return;

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await preferences.setBool(_permissionRequestedKey, true);
  }

  Future<void> scheduleReminderNotification(Reminder reminder) async {
    final id = reminder.id;
    if (!_isInitialized || id == null) return;

    await cancelReminder(id);
    if (!reminder.isActive) return;

    final matchComponents = switch (reminder.repeatType) {
      ReminderRepeatType.none => null,
      ReminderRepeatType.daily => DateTimeComponents.time,
      ReminderRepeatType.weekly => DateTimeComponents.dayOfWeekAndTime,
      ReminderRepeatType.monthly => DateTimeComponents.dayOfMonthAndTime,
    };
    final scheduledDate = _nextReminderDate(reminder);
    if (scheduledDate == null) return;

    await _notifications.zonedSchedule(
      id: id,
      title: 'یادآور',
      body: reminder.title,
      scheduledDate: scheduledDate,
      notificationDetails: _notificationDetails,
      androidScheduleMode: await _androidScheduleMode(),
      matchDateTimeComponents: matchComponents,
      payload: 'reminder:$id',
    );
  }

  Future<void> scheduleSubscriptionReminder(Subscription subscription) async {
    final id = subscription.id;
    if (!_isInitialized || id == null) return;

    await cancelReminder(id, isSubscription: true);
    if (subscription.isPaid) return;

    final date = subscription.dueDate.subtract(
      Duration(days: subscription.reminderDaysBefore),
    );
    final scheduledDate = tz.TZDateTime.from(date, tz.local);
    if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) return;

    await _notifications.zonedSchedule(
      id: _subscriptionNotificationId(id),
      title: 'یادآور سررسید',
      body:
          'سررسید ${subscription.title} تا '
          '${subscription.reminderDaysBefore} روز دیگر',
      scheduledDate: scheduledDate,
      notificationDetails: _notificationDetails,
      androidScheduleMode: await _androidScheduleMode(),
      payload: 'subscription:$id',
    );
  }

  Future<void> cancelReminder(int id, {bool isSubscription = false}) async {
    if (!_isInitialized) return;
    await _notifications.cancel(
      id: isSubscription ? _subscriptionNotificationId(id) : id,
    );
  }

  tz.TZDateTime? _nextReminderDate(Reminder reminder) {
    var date = tz.TZDateTime.from(reminder.dateTime, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (date.isAfter(now)) return date;

    switch (reminder.repeatType) {
      case ReminderRepeatType.none:
        return null;
      case ReminderRepeatType.daily:
        do {
          date = tz.TZDateTime(
            tz.local,
            date.year,
            date.month,
            date.day + 1,
            reminder.dateTime.hour,
            reminder.dateTime.minute,
            reminder.dateTime.second,
          );
        } while (!date.isAfter(now));
      case ReminderRepeatType.weekly:
        do {
          date = tz.TZDateTime(
            tz.local,
            date.year,
            date.month,
            date.day + 7,
            reminder.dateTime.hour,
            reminder.dateTime.minute,
            reminder.dateTime.second,
          );
        } while (!date.isAfter(now));
      case ReminderRepeatType.monthly:
        do {
          var year = date.year;
          var month = date.month + 1;
          if (month > 12) {
            month = 1;
            year++;
          }
          while (reminder.dateTime.day > _daysInMonth(year, month)) {
            month++;
            if (month > 12) {
              month = 1;
              year++;
            }
          }
          date = tz.TZDateTime(
            tz.local,
            year,
            month,
            reminder.dateTime.day,
            reminder.dateTime.hour,
            reminder.dateTime.minute,
            reminder.dateTime.second,
          );
        } while (!date.isAfter(now));
    }
    return date;
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canScheduleExactly = await android?.canScheduleExactNotifications();
    return canScheduleExactly == false
        ? AndroidScheduleMode.inexactAllowWhileIdle
        : AndroidScheduleMode.exactAllowWhileIdle;
  }

  int _subscriptionNotificationId(int id) => _subscriptionIdOffset + id;

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );
}
