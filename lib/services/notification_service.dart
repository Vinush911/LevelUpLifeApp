import 'package:flutter/material.dart'; // For TimeOfDay
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:math';

import '../models/timetable_entry.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static const List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static Future<void> init() async {
    // Wrap the entire initialization in a try/catch block
    try {
      // 1. Initialize Timezone Database
      tz.initializeTimeZones(); // This is synchronous (no 'await')

      // 2. Get local timezone
      print("NotificationService: Getting local timezone...");
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      print("NotificationService: Found local timezone: ${localTimezone.toString()}");

      // 3. Set local timezone
      tz.setLocalLocation(tz.getLocation(localTimezone.toString()));
      print("NotificationService: Timezone location set successfully.");

      // 4. Initialize Notification Plugin Settings
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
      print("NotificationService: Initialization complete.");

    } catch (e) {
      // THIS WILL SHOW US THE REAL ERROR
      print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      print("!!! ERROR INITIALIZING NOTIFICATION SERVICE: $e");
      print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
    }
  }

  static Future<void> requestPermissions() async {
    // For Android 13+
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // 🔹 NEW: Request exact alarm permission for Android 12+
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    // For iOS
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<int> scheduleTimetableEntry(TimetableEntry entry) async {
    // 1. Cancel any old notification this entry had
    if (entry.notificationId != null) {
      await cancelNotification(entry.notificationId!);
    }

    if (!entry.reminderEnabled) {
      return 0;
    }

    // 2. Generate a new unique ID for this notification
    final newNotificationId = Random().nextInt(2147483647);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'timetable_channel',
      'Timetable Reminders',
      channelDescription: 'Reminders for scheduled timetable entries',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    // --- vvv THIS IS THE FIX vvv ---
    // The iOS setting goes INSIDE the DarwinNotificationDetails
    const NotificationDetails notificationDetails =
        NotificationDetails(
            android: androidDetails,
            iOS: DarwinNotificationDetails(
              presentSound: true,
              // The old uiLocalNotificationDateInterpretation parameter
              // is no longer needed in this version of the package.
            )
        );
    // --- ^^^ THIS IS THE FIX ^^^ ---

    // 3. Schedule a notification for each selected day
    for (String day in entry.repeatDays) {
      final tz.TZDateTime scheduledTime = _nextInstanceOfDay(
        day,
        entry.startTime,
        entry.reminderTimeOffset,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        newNotificationId + _dayLabels.indexOf(day), // Create a unique ID per day
        entry.title,
        'Your scheduled event is starting in ${entry.reminderTimeOffset} minutes.',
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // We REMOVED the bad line from here
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }

    // 4. Return the *base* ID we used.
    return newNotificationId;
  }

  static Future<void> cancelNotification(int baseNotificationId) async {
    // Cancel all 7 potential notifications (Mon-Sun) associated with this base ID
    for (int i = 0; i < 7; i++) {
      await _flutterLocalNotificationsPlugin.cancel(baseNotificationId + i);
    }
  }

  static tz.TZDateTime _nextInstanceOfDay(String day, TimeOfDay time, int offsetMinutes) {
    final int targetWeekday = _dayLabels.indexOf(day) + 1; // 1 = Monday, 7 = Sunday

    tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    final reminderTime = time.hour * 60 + time.minute - offsetMinutes;
    final int reminderHour = reminderTime ~/ 60;
    final int reminderMinute = reminderTime % 60;

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminderHour,
      reminderMinute,
    );

    while (scheduledDate.weekday != targetWeekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}