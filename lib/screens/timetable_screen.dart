import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/timetable_entry.dart';
import 'edit_timetable_entry_screen.dart';
import '../services/notification_service.dart';

class TimetableScreen extends StatefulWidget {
  final String uid;
  const TimetableScreen({super.key, required this.uid});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final ScrollController _headerController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();

  // Dimensions for the Grid
  final double _hourHeight = 65.0;
  final double _dayWidth = 130.0;
  final double _timeColumnWidth = 60.0;

  // HOT-RELOAD PROOF: Initialize the controller directly so it never throws a LateError
  late final ScrollController _verticalBodyController = ScrollController(
    initialScrollOffset: ((DateTime.now().hour - 1) * _hourHeight) < 0
        ? 0
        : ((DateTime.now().hour - 1) * _hourHeight),
  );

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // OPTIMIZATION: Cache the stream so it doesn't re-fetch on every UI rebuild
  late final Stream<QuerySnapshot> _entriesStream;

  @override
  void initState() {
    super.initState();

    _entriesStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('timetable_entries')
        .snapshots();

    // Sync header scroll with body scroll perfectly
    _horizontalBodyController.addListener(() {
      if (_headerController.hasClients) {
        _headerController.jumpTo(_horizontalBodyController.offset);
      }
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _horizontalBodyController.dispose();
    _verticalBodyController.dispose();
    super.dispose();
  }

  // Generates a consistent, aesthetic color based on the title string
  Color _getColorForTitle(String title) {
    final colors = [
      Colors.pinkAccent.shade200,
      Colors.lightBlueAccent.shade700,
      Colors.amber.shade600,
      Colors.green.shade500,
      Colors.purpleAccent.shade200,
      Colors.orangeAccent.shade400,
      Colors.teal.shade400,
      Colors.indigoAccent.shade200,
    ];
    int hash = title.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  Future<void> _deleteEntry(TimetableEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent)),
        title: const Text("Delete Entry?", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete '${entry.title}'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text("Delete"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        if (entry.notificationId != null) {
          await NotificationService.instance.cancelNotification(entry.notificationId!);
        }
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('timetable_entries')
            .doc(entry.id)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Schedule updated.", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.amber),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _showEntryDetails(TimetableEntry entry) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF16213E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5))),
            title: Text(entry.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Text(entry.formatTime(context), style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ]
                  ),
                  const SizedBox(height: 12),
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.cyanAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.repeatDays.join(', '), style: const TextStyle(color: Colors.white70, height: 1.4))),
                      ]
                  ),
                  if (entry.reminderEnabled) ...[
                    const SizedBox(height: 12),
                    Row(
                        children: [
                          Icon(Icons.notifications_active, color: Colors.purple.shade200, size: 18),
                          const SizedBox(width: 8),
                          Text("Alert ${entry.reminderTimeOffset} min before", style: const TextStyle(color: Colors.white70)),
                        ]
                    )
                  ]
                ]
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close", style: TextStyle(color: Colors.grey))),
              IconButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteEntry(entry);
                },
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                tooltip: "Delete",
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditTimetableEntryScreen(uid: widget.uid, entry: entry)));
                },
                icon: const Icon(Icons.edit, size: 16),
                label: const Text("Edit"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.black),
              ),
            ]
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Weekly Master Plan", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _entriesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
          }
          final docs = snapshot.data?.docs ?? [];

          return Column(
            children: [
              _buildHeaderRow(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimeColumn(),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _verticalBodyController,
                        physics: const BouncingScrollPhysics(),
                        child: SingleChildScrollView(
                          controller: _horizontalBodyController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: _buildGrid(docs),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => EditTimetableEntryScreen(uid: widget.uid)),
          );
        },
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        tooltip: 'Add Entry',
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  // --- 1. Sticky Days Header ---
  Widget _buildHeaderRow() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        border: Border(bottom: BorderSide(color: Colors.purpleAccent.withOpacity(0.5), width: 2)),
      ),
      child: Row(
        children: [
          SizedBox(width: _timeColumnWidth), // Empty corner block
          Expanded(
            child: SingleChildScrollView(
              controller: _headerController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(), // Only scrolled via the body sync
              child: Row(
                children: List.generate(7, (index) {
                  final isToday = _days[index] == _days[DateTime.now().weekday - 1];
                  return Container(
                    width: _dayWidth,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isToday ? Colors.purpleAccent.withOpacity(0.15) : Colors.transparent,
                      border: const Border(right: BorderSide(color: Colors.white10)),
                    ),
                    child: Text(
                        _days[index].toUpperCase(),
                        style: TextStyle(
                            color: isToday ? Colors.purpleAccent.shade100 : Colors.grey.shade300,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5
                        )
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. Sticky Times Column ---
  Widget _buildTimeColumn() {
    return SingleChildScrollView(
      controller: _verticalBodyController,
      physics: const BouncingScrollPhysics(),
      child: Container(
        width: _timeColumnWidth,
        decoration: const BoxDecoration(
          color: Color(0xFF0F3460),
          border: Border(right: BorderSide(color: Colors.white12)),
        ),
        child: Column(
          children: List.generate(24, (index) {
            final isAm = index < 12;
            final displayHour = index == 0 ? 12 : (index > 12 ? index - 12 : index);
            final suffix = isAm ? "AM" : "PM";
            return Container(
              height: _hourHeight,
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 8, right: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.transparent)),
              ),
              child: Text(
                  "$displayHour $suffix",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w600)
              ),
            );
          }),
        ),
      ),
    );
  }

  // --- 3. The Interactive Grid & Blocks ---
  Widget _buildGrid(List<DocumentSnapshot> docs) {
    return Container(
      width: 7 * _dayWidth,
      height: 24 * _hourHeight,
      color: const Color(0xFF1A1A2E),
      child: Stack(
        children: [
          // Background Vertical Grid Lines
          Row(
            children: List.generate(7, (index) => Container(
              width: _dayWidth,
              decoration: BoxDecoration(
                  color: _days[index] == _days[DateTime.now().weekday - 1]
                      ? Colors.white.withOpacity(0.02) // Slight highlight for today
                      : Colors.transparent,
                  border: const Border(right: BorderSide(color: Colors.white10))
              ),
            )),
          ),
          // Background Horizontal Grid Lines
          Column(
            children: List.generate(24, (index) => Container(
                height: _hourHeight,
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white10))
                )
            )),
          ),

          // Draw Time Blocks
          ..._buildEntryBlocks(docs),

          // Current Time Indicator Line
          _buildCurrentTimeIndicator(),
        ],
      ),
    );
  }

  List<Widget> _buildEntryBlocks(List<DocumentSnapshot> docs) {
    List<Widget> blocks = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final entry = TimetableEntry.fromFirestore(doc);

      int startMin = data['startTimeMinutes'] as int? ?? 0;

      // Calculate duration safely based on typical field patterns
      int duration = 60; // default 1 hour
      if (data.containsKey('endTimeMinutes')) {
        duration = (data['endTimeMinutes'] as int) - startMin;
      } else if (data.containsKey('duration')) {
        duration = data['duration'] as int;
      }

      // Prevent negative or tiny blocks
      if (duration < 15) duration = 60;

      for (String day in entry.repeatDays) {
        int dayIndex = _days.indexOf(day);
        if (dayIndex == -1) continue;

        blocks.add(
            Positioned(
                left: dayIndex * _dayWidth,
                top: startMin * (_hourHeight / 60),
                width: _dayWidth,
                height: duration * (_hourHeight / 60),
                child: GestureDetector(
                    onTap: () => _showEntryDetails(entry),
                    child: Container(
                        margin: const EdgeInsets.only(top: 1, right: 1, left: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                            color: _getColorForTitle(entry.title).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                            ]
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  entry.title,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  maxLines: duration < 30 ? 1 : 2,
                                  overflow: TextOverflow.ellipsis
                              ),
                              if (duration >= 45)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                      entry.formatTime(context),
                                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis
                                  ),
                                ),
                            ]
                        )
                    )
                )
            )
        );
      }
    }
    return blocks;
  }

  // A glowing red line showing the exact current time
  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final topOffset = (now.hour * 60 + now.minute) * (_hourHeight / 60);

    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 4)]
              )
          ),
          Expanded(
            child: Container(
              height: 2,
              color: Colors.redAccent.withOpacity(0.8),
            ),
          )
        ],
      ),
    );
  }
}