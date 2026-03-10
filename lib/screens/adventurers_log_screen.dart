import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdventurersLogScreen extends StatefulWidget {
  final String uid;
  const AdventurersLogScreen({super.key, required this.uid});

  @override
  State<AdventurersLogScreen> createState() => _AdventurersLogScreenState();
}

class _AdventurersLogScreenState extends State<AdventurersLogScreen> {
  late int _selectedYear;
  List<int> _availableYears = [];

  // Interactive Selection
  DateTime? _selectedDate;
  Map<String, dynamic>? _selectedDateData;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _fetchAvailableYears();
  }

  Future<void> _fetchAvailableYears() async {
    final firestore = FirebaseFirestore.instance;
    final activityLogRef = firestore.collection('users').doc(widget.uid).collection('activity_log');

    try {
      // FIX: Order by the Document ID (which is formatted as yyyy-MM-dd) instead of timestamp.
      // This ensures older documents that were created BEFORE the timestamp field existed
      // are not ignored by Firestore.
      final firstLogSnapshot = await activityLogRef.orderBy(FieldPath.documentId).limit(1).get();

      int startYear = DateTime.now().year;
      if (firstLogSnapshot.docs.isNotEmpty) {
        // Parse the year directly from the document ID
        final parsedDate = DateTime.tryParse(firstLogSnapshot.docs.first.id);
        if (parsedDate != null) {
          startYear = parsedDate.year;
        }
      }

      final currentYear = DateTime.now().year;
      if (mounted) {
        setState(() {
          _availableYears = List<int>.generate(
              currentYear - startYear + 1,
                  (index) => currentYear - index
          );
          if (_availableYears.isEmpty) {
            _availableYears = [currentYear];
          }
          if (!_availableYears.contains(_selectedYear)) {
            _selectedYear = _availableYears.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableYears = [DateTime.now().year];
          _selectedYear = DateTime.now().year;
        });
      }
    }
  }

  // Parses any camelCase key from Firestore into a readable title safely
  String _formatKey(String key) {
    if (key.isEmpty) return 'Unknown Activity';
    String formatted = key.replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}');
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  // Chooses an icon based on the activity name dynamically
  IconData _getIconForKey(String key) {
    final lowerKey = key.toLowerCase();
    if (lowerKey.contains('quest')) return Icons.star;
    if (lowerKey.contains('gold') || lowerKey.contains('ledger')) return Icons.monetization_on;
    if (lowerKey.contains('exp')) return Icons.trending_up;
    if (lowerKey.contains('diary') || lowerKey.contains('note')) return Icons.book;
    if (lowerKey.contains('expense')) return Icons.shopping_cart;
    if (lowerKey.contains('skill')) return Icons.account_tree;
    return Icons.local_fire_department; // Default universal icon
  }

  // Determines the heatmap color intensity based on total activity actions
  Color _getColorForCount(int count) {
    if (count == 0) return Colors.black.withOpacity(0.3); // Empty background
    if (count <= 2) return Colors.purple.shade900;
    if (count <= 5) return Colors.purple.shade700;
    if (count <= 10) return Colors.purple.shade500;
    return Colors.purpleAccent; // Max intensity
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Adventurer's Log", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
        actions: [
          if (_availableYears.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: DropdownButton<int>(
                value: _selectedYear,
                dropdownColor: const Color(0xFF16213E),
                underline: const SizedBox(),
                icon: const Icon(Icons.calendar_today, color: Colors.purpleAccent, size: 18),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                items: _availableYears.map((year) {
                  return DropdownMenuItem<int>(
                    value: year,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(year.toString()),
                    ),
                  );
                }).toList(),
                onChanged: (year) {
                  if (year != null) {
                    setState(() {
                      _selectedYear = year;
                      _selectedDate = null; // Reset selection on year change
                      _selectedDateData = null;
                    });
                  }
                },
              ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('activity_log')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
          }

          // 1. Process all activities into a Date-String Map
          final Map<String, Map<String, dynamic>> activityByDate = {};

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;

              // FIX: Rely exclusively on the Document ID for the date.
              // This is 100% reliable since the ID is always 'yyyy-MM-dd'.
              DateTime? date = DateTime.tryParse(doc.id);

              if (date != null && date.year == _selectedYear) {
                final dateString = DateFormat('yyyy-MM-dd').format(date);
                activityByDate[dateString] = data;
              }
            }
          }

          // Update selected data if it exists
          if (_selectedDate != null) {
            final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
            _selectedDateData = activityByDate[selectedDateStr] ?? {};
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEATMAP COMPONENT ---
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.3), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "APP USAGE TRACKER - $_selectedYear",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 16),
                    _buildInteractiveHeatmap(activityByDate),
                    const SizedBox(height: 16),
                    _buildHeatmapLegend(),
                  ],
                ),
              ),

              // --- SELECTED DAY DETAILS COMPONENT ---
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildDetailsPanel(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInteractiveHeatmap(Map<String, Map<String, dynamic>> activityByDate) {
    // Use UTC to calculate the grid bounds. Calculating dates across Daylight Savings
    // Time changes causes standard DateTime difference to lose hours, breaking the grid.
    final firstDayOfYear = DateTime.utc(_selectedYear, 1, 1);
    final lastDayOfYear = DateTime.utc(_selectedYear, 12, 31);

    // Offset to make the grid start on a Monday (1 = Monday, 7 = Sunday)
    final int startOffset = firstDayOfYear.weekday - 1;
    final DateTime gridStartDate = firstDayOfYear.subtract(Duration(days: startOffset));

    final int totalDays = lastDayOfYear.difference(gridStartDate).inDays + 1;
    final int totalWeeks = (totalDays / 7).ceil();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- GITHUB STYLE MONTH LABELS ROW ---
          SizedBox(
            height: 16,
            width: totalWeeks * 18.0, // 14 width + 4 margin per week
            child: Stack(
              children: List.generate(totalWeeks, (weekIndex) {
                final currentDate = gridStartDate.add(Duration(days: weekIndex * 7));
                // Only place a label if it's the first week of the month
                if (currentDate.year == _selectedYear && currentDate.day <= 7) {
                  return Positioned(
                    left: weekIndex * 18.0,
                    child: Text(
                      DateFormat('MMM').format(currentDate),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ),
          ),

          // --- THE HEATMAP GRID ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(totalWeeks, (weekIndex) {
              return Column(
                children: List.generate(7, (dayIndex) {
                  final currentDateUtc = gridStartDate.add(Duration(days: (weekIndex * 7) + dayIndex));
                  // Convert back to local time safely for UI checks
                  final currentDate = DateTime(currentDateUtc.year, currentDateUtc.month, currentDateUtc.day);

                  // Don't show days outside the selected year
                  if (currentDate.year != _selectedYear) {
                    return Container(width: 14, height: 14, margin: const EdgeInsets.all(2));
                  }

                  final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);
                  final dayData = activityByDate[dateStr] ?? {};

                  // Calculate total activity count universally (numbers add up, non-numbers count as 1)
                  int totalActivityCount = 0;
                  dayData.forEach((key, value) {
                    if (key != 'timestamp') {
                      if (value is num) {
                        totalActivityCount += value.toInt();
                      } else {
                        totalActivityCount += 1;
                      }
                    }
                  });

                  final isSelected = _selectedDate != null &&
                      currentDate.year == _selectedDate!.year &&
                      currentDate.month == _selectedDate!.month &&
                      currentDate.day == _selectedDate!.day;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = currentDate;
                        _selectedDateData = dayData;
                      });
                    },
                    child: Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _getColorForCount(totalActivityCount),
                        borderRadius: BorderRadius.circular(3),
                        border: isSelected ? Border.all(color: Colors.amber, width: 2) : null,
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text("Less ", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        _buildLegendBox(0),
        _buildLegendBox(1),
        _buildLegendBox(4),
        _buildLegendBox(8),
        _buildLegendBox(12),
        Text(" More", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }

  Widget _buildLegendBox(int count) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _getColorForCount(count),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildDetailsPanel() {
    if (_selectedDate == null) {
      return Center(
        child: Text(
          "Tap a day on the map to view its history.",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
        ),
      );
    }

    final dateLabel = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!);

    // Filter out the timestamp so we only show the actual universal stats
    final Map<String, dynamic> stats = {};
    if (_selectedDateData != null) {
      _selectedDateData!.forEach((key, value) {
        if (key != 'timestamp') {
          stats[key] = value;
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_note, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              dateLabel,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Divider(color: Colors.white24, height: 24),

        if (stats.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.nights_stay_outlined, size: 60, color: Colors.grey.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    "No activities recorded on this day.\nThe realm was peaceful.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: stats.length,
              itemBuilder: (context, index) {
                final key = stats.keys.elementAt(index);
                final value = stats[key];

                return Card(
                  color: Colors.black.withOpacity(0.3),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.purpleAccent.withOpacity(0.2)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.withOpacity(0.2),
                      child: Icon(_getIconForKey(key), color: Colors.purpleAccent, size: 20),
                    ),
                    title: Text(
                      _formatKey(key),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    trailing: Text(
                      value is num ? "+$value" : "Done",
                      style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}