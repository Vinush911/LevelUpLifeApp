import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import 'package:intl/intl.dart'; // For formatting the date

class AchievementsScreen extends StatefulWidget {
  final String uid;
  const AchievementsScreen({super.key, required this.uid});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Assuming two categories for now: General & Combat. This can be expanded.
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Achievements"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "General"),
            Tab(text: "Combat"),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF1A1A2E),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAchievementList(context, "General"),
          _buildAchievementList(context, "Combat"),
        ],
      ),
    );
  }

  Widget _buildAchievementList(BuildContext context, String category) {
    return StreamBuilder<QuerySnapshot>(
      // --- NEW: Filtering achievements by category ---
      stream: FirebaseFirestore.instance.collection('achievements').where('category', isEqualTo: category).snapshots(),
      builder: (context, achievementSnapshot) {
        if (!achievementSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final achievements = achievementSnapshot.data!.docs;

        if (achievements.isEmpty) {
          return Center(child: Text("No achievements in this category yet.", style: TextStyle(color: Colors.grey.shade400)));
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }
            final user = User.fromFirestore(userSnapshot.data);
            final unlocked = user.unlockedAchievements;

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                final achievementDoc = achievements[index];
                final achievement = achievementDoc.data() as Map<String, dynamic>;
                final isUnlocked = unlocked.containsKey(achievementDoc.id);

                // --- NEW: Calculate progress for stat-based achievements ---
                double progress = 0.0;
                String progressText = '';
                final type = (achievement['type'] as String? ?? '').toUpperCase();

                if(!isUnlocked && type == 'STAT') {
                  final stat = (achievement['stat'] as String? ?? '').toUpperCase();
                  final threshold = (achievement['threshold'] as num? ?? 1).toDouble();
                  final currentValue = (user.stats[stat] ?? 0).toDouble();
                  if (threshold > 0) {
                    progress = (currentValue / threshold).clamp(0.0, 1.0);
                    progressText = "${currentValue.toInt()} / ${threshold.toInt()}";
                  }
                } else if (!isUnlocked && type == 'LEVEL') {
                  final threshold = (achievement['threshold'] as num? ?? 1).toDouble();
                  final currentValue = user.level.toDouble();
                  if (threshold > 0) {
                    progress = (currentValue / threshold).clamp(0.0, 1.0);
                    progressText = "${currentValue.toInt()} / ${threshold.toInt()}";
                  }
                }

                return _AchievementCard(
                  title: achievement['title'] ?? 'Achievement',
                  description: achievement['description'] ?? '',
                  isUnlocked: isUnlocked,
                  unlockedDate: isUnlocked ? unlocked[achievementDoc.id] : null,
                  progress: progress,
                  progressText: progressText,
                );
              },
            );
          },
        );
      },
    );
  }
}

// --- NEW: A dedicated widget for the achievement card UI ---
class _AchievementCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isUnlocked;
  final Timestamp? unlockedDate;
  final double progress;
  final String progressText;

  const _AchievementCard({
    required this.title,
    required this.description,
    required this.isUnlocked,
    this.unlockedDate,
    this.progress = 0.0,
    this.progressText = '',
  });

  @override
  Widget build(BuildContext context) {
    final bool isInProgress = progress > 0 && !isUnlocked;
    final Color cardColor = isUnlocked ? Colors.amber.withOpacity(0.1) : Colors.black.withOpacity(0.2);
    final Color borderColor = isUnlocked ? Colors.amber : (isInProgress ? Colors.blueAccent : Colors.grey.shade800);
    final IconData iconData = isUnlocked ? Icons.emoji_events : (isInProgress ? Icons.trending_up : Icons.lock);

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconData, color: borderColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isUnlocked ? Colors.amber : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: isUnlocked ? Colors.amber.shade200 : Colors.grey.shade400),
            ),
            if (isInProgress || isUnlocked) const Divider(height: 24, color: Colors.grey),
            if (isInProgress)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade700,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(progressText, style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                  ),
                ],
              )
            else if (isUnlocked && unlockedDate != null)
              Center(
                child: Text(
                  "Unlocked on: ${DateFormat.yMMMd().format(unlockedDate!.toDate())}",
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.greenAccent.withOpacity(0.8), fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
