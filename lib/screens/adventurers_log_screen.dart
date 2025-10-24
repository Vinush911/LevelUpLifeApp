import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:async';

class AdventurersLogScreen extends StatefulWidget {
  final String uid;
  const AdventurersLogScreen({super.key, required this.uid});

  @override
  State<AdventurersLogScreen> createState() => _AdventurersLogScreenState();
}

class _AdventurersLogScreenState extends State<AdventurersLogScreen> {
  late int _selectedYear;
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _fetchAvailableYears();
  }

  Future<void> _fetchAvailableYears() async {
    final firestore = FirebaseFirestore.instance;
    final activityLogRef = firestore.collection('users').doc(widget.uid).collection('activity_log');
    final firstLogSnapshot = await activityLogRef.orderBy('timestamp').limit(1).get();

    int startYear = DateTime.now().year;
    if (firstLogSnapshot.docs.isNotEmpty) {
      final firstLog = firstLogSnapshot.docs.first.data();
      final firstLogDate = (firstLog['timestamp'] as Timestamp).toDate();
      startYear = firstLogDate.year;
    }

    final currentYear = DateTime.now().year;
    if (mounted) {
      setState(() {
        _availableYears = List<int>.generate(currentYear - startYear + 1, (index) => currentYear - index);
      });
    }
  }

  Map<String, int> _calculateStreaks(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return {'current': 0, 'longest': 0};

    final dates = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['timestamp'] as Timestamp).toDate();
    }).toSet().toList();

    dates.sort((a, b) => b.compareTo(a));

    int longestStreak = 0;
    int currentStreak = 0;

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    if (dates.isNotEmpty) {
      final mostRecentLogDate = DateTime(dates.first.year, dates.first.month, dates.first.day);
      if(mostRecentLogDate == todayDateOnly || mostRecentLogDate == todayDateOnly.subtract(const Duration(days: 1))) {
        currentStreak = 1;
        longestStreak = 1;
      }
    }

    for (int i = 0; i < dates.length - 1; i++) {
      final dateOnly = DateTime(dates[i].year, dates[i].month, dates[i].day);
      final nextDateOnly = DateTime(dates[i+1].year, dates[i+1].month, dates[i+1].day);

      if (dateOnly.subtract(const Duration(days: 1)) == nextDateOnly) {
        currentStreak++;
      } else {
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }
        if (dateOnly.difference(nextDateOnly).inDays > 1) {
          currentStreak = 1;
        }
      }
    }
    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    if (dates.isNotEmpty) {
      final mostRecentDate = DateTime(dates.first.year, dates.first.month, dates.first.day);
      if(todayDateOnly.difference(mostRecentDate).inDays > 1){
        currentStreak = 0;
      }
    } else {
      currentStreak = 0;
    }


    return {'current': currentStreak, 'longest': longestStreak};
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Adventurer's Log"),
        backgroundColor: const Color(0xFF0d1117),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0d1117),
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('activity_log')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: Text("No data available.", style: TextStyle(color: Colors.grey)));
        }

        final allDocs = snapshot.data!.docs;
        final streaks = _calculateStreaks(allDocs);

        final docsForYear = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final date = (data['timestamp'] as Timestamp).toDate();
          return date.year == _selectedYear;
        }).toList();

        final Map<String, int> activityData = {};
        for (var doc in docsForYear) {
          final data = doc.data() as Map<String, dynamic>;
          final date = (data['timestamp'] as Timestamp).toDate();
          final dateString = DateFormat('yyyy-MM-dd').format(date);
          activityData[dateString] = (activityData[dateString] ?? 0) + (data['questsCompleted'] as num? ?? 0).toInt();
        }

        final totalContributions = activityData.values.fold(0, (sum, count) => sum + count);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildYearSelector(),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildStreaksSummary(streaks),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade800),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$totalContributions contributions in $_selectedYear",
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ContributionGraph(
                          activityData: activityData,
                          year: _selectedYear,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: _buildLegend(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildStreaksSummary(Map<String, int> streaks) {
    final currentStreak = streaks['current'] ?? 0;
    final longestStreak = streaks['longest'] ?? 0;

    return Card(
      color: const Color(0xFF161b22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade800),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16.0,
          runSpacing: 16.0,
          children: [
            _buildStreakItem(
              context: context,
              count: currentStreak,
              label: 'Current Streak',
              icon: Icons.whatshot,
              color: Colors.orange,
            ),
            _buildStreakItem(
              context: context,
              count: longestStreak,
              label: 'Longest Streak',
              icon: Icons.star,
              color: Colors.amber,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildStreakItem({required BuildContext context, required int count, required String label, required IconData icon, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildYearSelector() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableYears.length,
        itemBuilder: (context, index) {
          final year = _availableYears[index];
          final isSelected = year == _selectedYear;
          return GestureDetector(
            onTap: () => setState(() => _selectedYear = year),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blueAccent : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  year.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade400,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Less", style: TextStyle(color: Colors.grey)),
        const SizedBox(width: 8),
        ..._getColors().map((color) => Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        )).toList(),
        const SizedBox(width: 8),
        const Text("More", style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  List<Color> _getColors() => [
    const Color(0xFF161b22),
    const Color(0xFF0e4429),
    const Color(0xFF006d32),
    const Color(0xFF26a641),
    const Color(0xFF39d353),
  ];
}

class ContributionGraph extends StatefulWidget {
  final Map<String, int> activityData;
  final int year;
  const ContributionGraph({super.key, required this.activityData, required this.year});

  @override
  State<ContributionGraph> createState() => _ContributionGraphState();
}

class _ContributionGraphState extends State<ContributionGraph> {
  Offset? _tapPosition;
  String _tooltipText = '';
  Timer? _tooltipTimer;
  static const double daySize = 18.0;

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    _tooltipTimer?.cancel();
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = details.localPosition;

    const double leftOffset = 40;
    const double topOffset = 30;

    final col = ((localPosition.dx - leftOffset) / daySize).floor();
    final row = ((localPosition.dy - topOffset) / daySize).floor();

    final yearStartDate = DateTime(widget.year, 1, 1);
    final firstDay = yearStartDate.subtract(Duration(days: yearStartDate.weekday - 1));

    // --- FIX: Correct boundary check for columns ---
    if (row < 0 || row > 6 || col < 0 || col > 52) {
      _hideTooltip();
      return;
    }

    final tappedDate = firstDay.add(Duration(days: (col * 7) + row));

    final dateString = DateFormat('yyyy-MM-dd').format(tappedDate);
    final count = widget.activityData[dateString] ?? 0;
    final questsString = count == 1 ? "quest" : "quests";

    if (mounted) {
      setState(() {
        _tapPosition = localPosition;
        _tooltipText = "$count $questsString on ${DateFormat.yMMMd().format(tappedDate)}";
      });

      _tooltipTimer = Timer(const Duration(seconds: 4), () {
        _hideTooltip();
      });
    }
  }

  void _hideTooltip() {
    if (mounted && _tapPosition != null) {
      setState(() {
        _tapPosition = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const double leftOffset = 40;
    const double topOffset = 30;
    const double graphWidth = leftOffset + (53 * daySize);
    const double graphHeight = topOffset + (7 * daySize);

    return GestureDetector(
      onTapDown: _handleTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: graphWidth,
            height: graphHeight,
            child: CustomPaint(
              size: Size.infinite,
              painter: _ContributionGraphPainter(
                activityData: widget.activityData,
                daySize: daySize,
                year: widget.year,
              ),
            ),
          ),
          if (_tapPosition != null)
            Positioned(
              left: _tapPosition!.dx,
              top: _tapPosition!.dy - 40,
              child: _buildTooltip(),
            ),
        ],
      ),
    );
  }

  Widget _buildTooltip() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade700)
        ),
        child: Text(_tooltipText, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _ContributionGraphPainter extends CustomPainter {
  final Map<String, int> activityData;
  final double daySize;
  final int year;

  _ContributionGraphPainter({required this.activityData, required this.daySize, required this.year});

  @override
  void paint(Canvas canvas, Size size) {
    final double spacing = daySize * 0.15;
    final double squareSize = daySize - spacing;
    const double leftOffset = 40;
    const double topOffset = 30;

    final yearStartDate = DateTime(year, 1, 1);
    final firstDay = yearStartDate.subtract(Duration(days: yearStartDate.weekday - 1));

    _drawDayLabels(canvas, topOffset, squareSize);
    _drawMonthLabels(canvas, leftOffset, firstDay, daySize, size.width);

    // --- FIX: Correctly calculate the number of weeks to draw ---
    final lastDay = DateTime(year, 12, 31);
    final totalDays = lastDay.difference(firstDay).inDays;
    final totalWeeks = (totalDays / 7).ceil();

    for (int i = 0; i <= totalWeeks * 7; i++) {
      final date = firstDay.add(Duration(days: i));
      if (date.year != year) continue;

      final int week = date.difference(firstDay).inDays ~/ 7;
      final int dayOfWeek = date.weekday -1;

      final double x = week * daySize + leftOffset;
      final double y = dayOfWeek * daySize + topOffset;

      final dateString = DateFormat('yyyy-MM-dd').format(date);
      final count = activityData[dateString] ?? 0;

      final paint = Paint()..color = _getColorForCount(count);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, squareSize, squareSize), const Radius.circular(3)), paint);
    }
  }

  void _drawDayLabels(Canvas canvas, double topOffset, double squareSize) {
    final days = ['Mon', 'Wed', 'Fri'];
    final textStyle = TextStyle(color: Colors.grey.shade400, fontSize: 12);
    for (int i = 0; i < days.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: days[i], style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final y = topOffset + (squareSize / 2) + (daySize * (1 + (i*2))) - (painter.height / 2);
      painter.paint(canvas, Offset(5, y));
    }
  }

  void _drawMonthLabels(Canvas canvas, double leftOffset, DateTime firstDay, double daySize, double canvasWidth) {
    final textStyle = TextStyle(color: Colors.grey.shade400, fontSize: 12);

    for (int i = 1; i <= 12; i++) {
      final firstDayOfMonth = DateTime(year, i, 1);
      // --- FIX: Correctly calculate the week index for the label ---
      final daysFromStart = firstDayOfMonth.difference(firstDay).inDays;
      final weekIndex = (daysFromStart / 7).floor();

      final painter = TextPainter(
        text: TextSpan(text: DateFormat.MMM().format(firstDayOfMonth), style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final x = leftOffset + (weekIndex * daySize);

      if (x < canvasWidth - painter.width && x >= leftOffset) {
        painter.paint(canvas, Offset(x, 0));
      }
    }
  }


  Color _getColorForCount(int count) {
    if (count == 0) {
      return const Color(0xFF161b22);
    } else if (count <= 2) {
      return const Color(0xFF0e4429);
    } else if (count <= 5) {
      return const Color(0xFF006d32);
    } else if (count <= 10) {
      return const Color(0xFF26a641);
    } else {
      return const Color(0xFF39d353);
    }
  }

  @override
  bool shouldRepaint(covariant _ContributionGraphPainter oldDelegate) {
    return oldDelegate.activityData != activityData || oldDelegate.daySize != daySize || oldDelegate.year != year;
  }
}

