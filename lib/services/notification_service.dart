import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../main.dart'; // navigatorKey
import '../models/timetable_entry.dart';
import '../screens/notification_test_screen.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  /// MUST be called ONCE before runApp
  Future<void> init() async {
    await _initTimezone();

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings =
    InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    const androidChannel = AndroidNotificationChannel(
      'default_channel',
      'Default Notifications',
      description: 'App notifications',
      importance: Importance.high,
    );

    final androidPlugin =
    _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(androidChannel);
  }

  /// 🔥 REQUIRED timezone initialization
  Future<void> _initTimezone() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.local);
  }



  /// Android 13+ permission
  Future<void> requestPermissions() async {
    final androidPlugin =
    _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
  }

  /// 🔔 Notification tap handler
  static void _onNotificationTap(NotificationResponse response) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => const NotificationTestScreen(),
      ),
    );
  }

  /// Test notification
  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails =
    NotificationDetails(android: androidDetails);

    await _plugin.show(
      0,
      'Test Notification',
      'Tap to open screen',
      notificationDetails,
      payload: jsonEncode({'type': 'test'}),
    );
  }

  /// Cancel notification
  Future<void> cancelNotification(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  /// Timetable notification (stub – safe)
  Future<int?> scheduleTimetableEntry(TimetableEntry entry) async {
    if (entry.notificationId != null) {
      await cancelNotification(entry.notificationId!);
    }

    final int newNotificationId =
    DateTime.now().millisecondsSinceEpoch.remainder(100000);

    return newNotificationId;
  }

  /// ✅ DAILY DIARY REMINDER (CORRECT)
  Future<int> scheduleDailyDiaryReminder({
    required int hour,
    required int minute,
  }) async {
    final int notificationId =
    DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails =
    NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      notificationId,
      'Diary Reminder',
      'Don\'t forget to write today ✍️',
      scheduledTime,
      notificationDetails,
      androidScheduleMode:
      AndroidScheduleMode.exactAllowWhileIdle,

      matchDateTimeComponents: DateTimeComponents.time,
    );

    return notificationId;
  }
}
