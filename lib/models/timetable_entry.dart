import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TimetableEntry {
  final String id;
  final String title;
  final int startTimeMinutes; // Minutes from midnight, e.g., 9:30 AM = 570
  final int endTimeMinutes;   // Minutes from midnight
  final List<String> repeatDays; // e.g., ['Mon', 'Tue', 'Wed']
  final bool reminderEnabled;
  final int reminderTimeOffset; // Minutes before the start time
  final int? notificationId; // <<<--- ADD THIS FIELD

  TimetableEntry({
    required this.id,
    required this.title,
    required this.startTimeMinutes,
    required this.endTimeMinutes,
    required this.repeatDays,
    required this.reminderEnabled,
    required this.reminderTimeOffset,
    this.notificationId, // <<<--- ADD THIS
  });

  // Helper to convert TimeOfDay to minutes
  static int timeOfDayToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  // Helper to convert minutes to TimeOfDay
  TimeOfDay get startTime => TimeOfDay(hour: startTimeMinutes ~/ 60, minute: startTimeMinutes % 60);
  TimeOfDay get endTime => TimeOfDay(hour: endTimeMinutes ~/ 60, minute: endTimeMinutes % 60);

  // Helper to format time for display
  String formatTime(BuildContext context) {
    return '${startTime.format(context)} - ${endTime.format(context)}';
  }

  factory TimetableEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimetableEntry(
      id: doc.id,
      title: data['title'] ?? 'Untitled',
      startTimeMinutes: (data['startTimeMinutes'] as num? ?? 0).toInt(),
      endTimeMinutes: (data['endTimeMinutes'] as num? ?? 0).toInt(),
      repeatDays: List<String>.from(data['repeatDays'] ?? []),
      reminderEnabled: data['reminderEnabled'] ?? false,
      reminderTimeOffset: (data['reminderTimeOffset'] as num? ?? 5).toInt(),
      notificationId: (data['notificationId'] as num?)?.toInt(), // <<<--- ADD THIS
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'startTimeMinutes': startTimeMinutes,
      'endTimeMinutes': endTimeMinutes,
      'repeatDays': repeatDays,
      'reminderEnabled': reminderEnabled,
      'reminderTimeOffset': reminderTimeOffset,
      'notificationId': notificationId, // <<<--- ADD THIS
    };
  }
}