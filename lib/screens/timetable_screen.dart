import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/timetable_entry.dart';
import 'edit_timetable_entry_screen.dart';
import '../services/notification_service.dart'; // <<<--- ADD THIS IMPORT

class TimetableScreen extends StatefulWidget {
  final String uid;
  const TimetableScreen({super.key, required this.uid});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  late Stream<QuerySnapshot> _entriesStream;

  // Weekday format: Mon, Tue, etc.
  final List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _entriesStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('timetable_entries')
        .snapshots();
  }

  String _getWeekdayString(DateTime date) {
    // DateTime.weekday returns 1 for Monday and 7 for Sunday
    return _dayLabels[date.weekday - 1];
  }

  // --- vvv THIS FUNCTION IS UPDATED vvv ---
  Future<void> _deleteEntry(TimetableEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Entry?"),
        content: Text("Are you sure you want to delete '${entry.title}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        // 1. Cancel the notification first
        if (entry.notificationId != null) {
          await NotificationService.cancelNotification(entry.notificationId!);
        }

        // 2. Delete the document from Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('timetable_entries')
            .doc(entry.id)
            .delete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting entry: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
  // --- ^^^ THIS FUNCTION IS UPDATED ^^^ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Timetable"),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              DateFormat.yMMMMEEEEd().format(_selectedDay ?? DateTime.now()),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: _buildEntryList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditTimetableEntryScreen(uid: widget.uid),
            ),
          );
        },
        tooltip: 'Add Entry',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEntryList() {
    final selectedWeekday = _getWeekdayString(_selectedDay ?? DateTime.now());

    return StreamBuilder<QuerySnapshot>(
      stream: _entriesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No timetable entries found."));
        }

        final entries = snapshot.data!.docs
            .map((doc) => TimetableEntry.fromFirestore(doc))
            .where((entry) => entry.repeatDays.contains(selectedWeekday))
            .toList();

        if (entries.isEmpty) {
          return Center(child: Text("No entries scheduled for $selectedWeekday."));
        }

        // Sort by start time
        entries.sort((a, b) => a.startTimeMinutes.compareTo(b.startTimeMinutes));

        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Text(entry.startTime.format(context).split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), // Just "9:30"
                ),
                title: Text(entry.title),
                subtitle: Text(entry.formatTime(context)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if(entry.reminderEnabled) Icon(Icons.notifications_active, size: 18, color: Colors.purple.shade200), // <<< UPDATED ICON
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: "Edit",
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EditTimetableEntryScreen(uid: widget.uid, entry: entry),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                      tooltip: "Delete",
                      onPressed: () => _deleteEntry(entry),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}