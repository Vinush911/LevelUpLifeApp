import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../main.dart'; // For navigatorKey
import '../models/timetable_entry.dart';
import '../screens/notification_test_screen.dart';

// Top level function for background notification taps
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('Notification tapped in background: ${notificationResponse.actionId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  // --- RESERVED NOTIFICATION IDs ---
  static const int _diaryId = 99999;
  static const int _energyId = 88888;
  static const int _questId = 77777;
  static const int _inactivityId = 66666;
  static const int _streakId = 55555;

  /// MUST be called ONCE before runApp
  Future<void> init() async {
    await _initTimezone();

    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create a base channel for Android 8.0+
    const androidChannel = AndroidNotificationChannel(
      'default_channel',
      'Default Notifications',
      description: 'Standard application notifications',
      importance: Importance.max,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);
  }

  /// REQUIRED timezone initialization for scheduled notifications
  Future<void> _initTimezone() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.local);
  }

  /// Request permissions from the user (Android 12 & 13+ Support)
  Future<void> requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Handles routing when a notification is tapped
  void _onNotificationTap(NotificationResponse response) {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const NotificationTestScreen()),
      );
    }
  }

  /// Cancel a standard notification
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  // ===========================================================================
  // 🗡️ RPG IMMERSIVE NOTIFICATIONS (WITH CUSTOM SOUNDS)
  // ===========================================================================

  /// 1. ENERGY FULL ALERT
  Future<void> scheduleEnergyFullNotification(DateTime energyFullTime) async {
    final tz.TZDateTime scheduledTime = tz.TZDateTime.from(energyFullTime, tz.local);

    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    const androidDetails = AndroidNotificationDetails(
      'energy_channel',
      'Energy Restoration',
      channelDescription: 'Alerts when your energy is fully restored',
      importance: Importance.high,
      priority: Priority.high,
      color: Colors.yellowAccent,
      // Custom Sound for Android (No extension)
      sound: RawResourceAndroidNotificationSound('level_up'),
    );
    const iosDetails = DarwinNotificationDetails(
      // Custom Sound for iOS (Requires extension)
      sound: 'level_up.mp3',
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      _energyId,
      'Energy Fully Restored! ⚡',
      'Your Energy is at maximum capacity, Adventurer! The realm awaits.',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// 2. DAILY QUEST BOARD RESET
  Future<void> scheduleDailyQuestReset({int hour = 6, int minute = 0}) async {
    tz.TZDateTime scheduledTime = _nextInstanceOfTime(hour, minute);

    const androidDetails = AndroidNotificationDetails(
      'quest_channel',
      'Quest Board Reset',
      channelDescription: 'Daily quest resets and updates',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: Colors.amber,
      sound: RawResourceAndroidNotificationSound('level_up'),
    );
    const iosDetails = DarwinNotificationDetails(
      sound: 'level_up.mp3',
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      _questId,
      'Quest Board Updated 📜',
      'New bounties have been posted! Earn your gold today.',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 3. INACTIVITY / "MISSED YOU" REMINDER
  Future<void> scheduleInactivityReminder() async {
    await _plugin.cancel(_inactivityId);

    final tz.TZDateTime scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(days: 3));

    const androidDetails = AndroidNotificationDetails(
      'inactivity_channel',
      'Guild Summons',
      channelDescription: 'Reminders to return to the app',
      importance: Importance.high,
      priority: Priority.high,
      color: Colors.redAccent,
      sound: RawResourceAndroidNotificationSound('level_up'),
    );
    const iosDetails = DarwinNotificationDetails(
      sound: 'level_up.mp3',
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      _inactivityId,
      'The Guild Misses You! ⚔️',
      'Return to the Tavern to continue your journey, Adventurer.',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// 4. SAVE YOUR STREAK WARNING
  Future<void> scheduleStreakWarning({int hour = 21, int minute = 0}) async {
    tz.TZDateTime scheduledTime = _nextInstanceOfTime(hour, minute);

    const androidDetails = AndroidNotificationDetails(
      'streak_channel',
      'Streak Warnings',
      channelDescription: 'Reminders to save your daily streak',
      importance: Importance.high,
      priority: Priority.high,
      color: Colors.orangeAccent,
      sound: RawResourceAndroidNotificationSound('level_up'),
    );
    const iosDetails = DarwinNotificationDetails(
      sound: 'level_up.mp3',
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      _streakId,
      'Save Your Streak! 🔥',
      'Careful! Your daily logging streak is about to break!',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Call this when the user logs an activity so they don't get annoyed by the 9 PM alarm today!
  Future<void> dismissStreakWarningForToday({int hour = 21, int minute = 0}) async {
    await _plugin.cancel(_streakId);

    tz.TZDateTime scheduledTime = _nextInstanceOfTime(hour, minute);
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    if (scheduledTime.year == now.year && scheduledTime.month == now.month && scheduledTime.day == now.day) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'streak_channel',
      'Streak Warnings',
      importance: Importance.high,
      priority: Priority.high,
      color: Colors.orangeAccent,
      sound: RawResourceAndroidNotificationSound('level_up'),
    );
    const iosDetails = DarwinNotificationDetails(
      sound: 'level_up.mp3',
    );

    await _plugin.zonedSchedule(
      _streakId,
      'Save Your Streak! 🔥',
      'Careful! Your daily logging streak is about to break!',
      scheduledTime,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ===========================================================================
  // 🕒 STANDARD APP NOTIFICATIONS (Timetable & Diary)
  // ===========================================================================

  Future<int> scheduleDailyDiaryReminder({required int hour, required int minute}) async {
    tz.TZDateTime scheduledTime = _nextInstanceOfTime(hour, minute);
    const androidDetails = AndroidNotificationDetails(
      'default_channel', 'Default Notifications',
      importance: Importance.high, priority: Priority.high, color: Colors.purpleAccent,
    );
    await _plugin.zonedSchedule(
      _diaryId,
      'Diary Reminder',
      "Don't forget to log your adventures for today! ✍️",
      scheduledTime,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return _diaryId;
  }

  Future<void> cancelTimetableEntry(int baseId) async {
    for (int i = 0; i < 7; i++) {
      await _plugin.cancel(baseId + i);
    }
  }

  Future<int?> scheduleTimetableEntry(TimetableEntry entry) async {
    if (entry.notificationId != null) await cancelTimetableEntry(entry.notificationId!);
    if (!entry.reminderEnabled || entry.repeatDays.isEmpty) return null;

    final int baseNotificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000) * 10;
    int totalMinutes = entry.startTimeMinutes - entry.reminderTimeOffset;

    int dayOffset = 0;
    if (totalMinutes < 0) {
      totalMinutes += 24 * 60;
      dayOffset = -1;
    }

    int notifyHour = totalMinutes ~/ 60;
    int notifyMinute = totalMinutes % 60;

    const androidDetails = AndroidNotificationDetails(
      'timetable_channel', 'Timetable Reminders',
      importance: Importance.high, priority: Priority.high, color: Colors.lightBlueAccent,
    );
    const details = NotificationDetails(android: androidDetails);

    for (int i = 0; i < entry.repeatDays.length; i++) {
      int targetWeekday = _stringToWeekday(entry.repeatDays[i]);
      if (dayOffset == -1) {
        targetWeekday -= 1;
        if (targetWeekday == 0) targetWeekday = DateTime.sunday;
      }
      tz.TZDateTime scheduledDate = _nextInstanceOfWeekdayAndTime(targetWeekday, notifyHour, notifyMinute);

      await _plugin.zonedSchedule(
        baseNotificationId + i,
        'Upcoming: ${entry.title}',
        'Starts in ${entry.reminderTimeOffset} minutes!',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
    return baseNotificationId;
  }

  // --- INTERNAL TIME HELPER FUNCTIONS ---

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfWeekdayAndTime(int weekday, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  int _stringToWeekday(String day) {
    switch (day) {
      case 'Mon': return DateTime.monday;
      case 'Tue': return DateTime.tuesday;
      case 'Wed': return DateTime.wednesday;
      case 'Thu': return DateTime.thursday;
      case 'Fri': return DateTime.friday;
      case 'Sat': return DateTime.saturday;
      case 'Sun': return DateTime.sunday;
      default: return DateTime.monday;
    }
  }
}