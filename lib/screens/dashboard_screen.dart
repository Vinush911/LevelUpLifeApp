import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../models/avatars.dart';
import 'daily_rewards_screen.dart';
import 'ledger_screen.dart'; // 1️⃣ Imported the new Ledger Screen
import 'dart:async';
import 'dart:math';

class DashboardScreen extends StatefulWidget {
  final String uid;
  const DashboardScreen({super.key, required this.uid});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _energyTimer;
  String _energyCountdown = "00:00";

  @override
  void dispose() {
    _energyTimer?.cancel();
    super.dispose();
  }

  void _startEnergyTimer(User user) {
    _energyTimer?.cancel();

    if (user.currentEnergy >= user.maxEnergy) {
      if (mounted && _energyCountdown != "Full") {
        setState(() => _energyCountdown = "Full");
      }
      return;
    }

    final lastRecharge = user.lastEnergyRecharge.toDate();
    final timePassedSinceLast = DateTime.now().difference(lastRecharge);
    final secondsPassedInCycle = timePassedSinceLast.inSeconds % 300; // 300 seconds = 5 minutes
    final secondsToNextPoint = 300 - secondsPassedInCycle;

    _energyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remainingSeconds = secondsToNextPoint - timer.tick;

      if (remainingSeconds <= 0) {
        if (mounted) {
          setState(() {
            _energyCountdown = "Ready!";
          });
        }
        timer.cancel();
      } else {
        final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
        final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
        if (mounted) setState(() => _energyCountdown = "$minutes:$seconds");
      }
    });
  }


  void _showEnergyDialog(BuildContext context) {
    Timer? dialogTimer;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (mounted) {
                setDialogState(() {});
              } else {
                timer.cancel();
              }
            });

            return AlertDialog(
              title: const Text("Energy Regeneration"),
              content: Text("Next energy point in: $_energyCountdown"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      dialogTimer?.cancel();
    });
  }


  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(widget.uid);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = User.fromFirestore(snapshot.data);
          user.regenerateEnergy();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _startEnergyTimer(user);
            }
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserHeader(user),
                const SizedBox(height: 24),
                _buildDailyRewardPrompt(context, user),
                _buildSectionHeader("Daily Activity"),
                const SizedBox(height: 12),
                _buildDailyActivitySummary(context, widget.uid),
                const SizedBox(height: 24),
                _buildSectionHeader("Character Stats"),
                const SizedBox(height: 12),
                _buildStatsCarousel(user),
                const SizedBox(height: 24),
                _buildSectionHeader("Active Quests"),
                const SizedBox(height: 12),
                _buildActiveQuestsList(context, widget.uid),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyRewardPrompt(BuildContext context, User user) {
    final now = DateTime.now();
    final lastLoginDate = user.lastLogin.toDate();
    final isSameDay = now.year == lastLoginDate.year &&
        now.month == lastLoginDate.month &&
        now.day == lastLoginDate.day;

    if (isSameDay) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Card(
        color: Colors.purpleAccent.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.purpleAccent, width: 1),
        ),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => DailyRewardsScreen(uid: widget.uid)),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard, color: Colors.purpleAccent, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Daily Reward Available!",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Tap here to claim your daily prize.",
                        style: TextStyle(color: Colors.grey.shade300),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildUserHeader(User user) {
    final double progress = user.nextLevelExp() > 0 ? user.exp / user.nextLevelExp() : 0.0;
    final imageUrl = user.avatarUrl ?? avatarUrls.first;

    return Card(
      color: const Color(0xFF16213E),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundImage: NetworkImage(imageUrl),
                  onBackgroundImageError: (_, __) {},
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('" ${user.title} "', style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.purple.shade200)),
                      if (user.userClass != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('[${user.userClass}]', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // --- FIXED: Replaced Row with Wrap to prevent RenderFlex overflow ---
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8.0, // Space between items horizontally
              runSpacing: 8.0, // Space between items vertically if they wrap
              children: [
                GestureDetector(
                  onTap: () => _showEnergyDialog(context),
                  child: Chip(
                    avatar: const Icon(Icons.flash_on, color: Colors.black, size: 18),
                    label: Text('${user.currentEnergy}/${user.maxEnergy}'),
                    backgroundColor: Colors.lightBlueAccent,
                    labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.monetization_on, color: Colors.black, size: 18),
                  label: Text(
                    user.gold.toString(),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.amber,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LedgerScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('LVL ${user.level}', style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade700,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                  '${user.exp.toStringAsFixed(0)} / ${user.nextLevelExp().toStringAsFixed(0)} EXP',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          height: 24,
          width: 4,
          decoration: BoxDecoration(
            color: Colors.purpleAccent,
            borderRadius: BorderRadius.circular(2),
          ),
          margin: const EdgeInsets.only(right: 12),
        ),
        Text(title,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildStatsCarousel(User user) {
    final stats = ['STR', 'DEX', 'END', 'INT', 'WIS', 'CHA'];
    final Map<String, IconData> statIcons = {
      'STR': Icons.fitness_center,
      'DEX': Icons.flash_on,
      'END': Icons.shield,
      'INT': Icons.psychology,
      'WIS': Icons.self_improvement,
      'CHA': Icons.star,
    };
    final Map<String, Color> statColors = {
      'STR': Colors.redAccent,
      'DEX': Colors.blueAccent,
      'END': Colors.greenAccent,
      'INT': Colors.purpleAccent,
      'WIS': Colors.tealAccent,
      'CHA': Colors.orangeAccent,
    };

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final statName = stats[index];
          final statValue = user.stats[statName] ?? 10;
          final iconData = statIcons[statName] ?? Icons.help;
          final color = statColors[statName] ?? Colors.grey;

          final double progress = (statValue / 100).clamp(0.0, 1.0);

          return AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(iconData, color: color, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        statValue.toString(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                      Text(
                        statName,
                        style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyActivitySummary(BuildContext context, String uid) {
    return Card(
      color: const Color(0xFF16213E),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('daily_quests').snapshots(),
            builder: (context, dailyQuestsSnapshot) {
              if (!dailyQuestsSnapshot.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              final totalDailies = dailyQuestsSnapshot.data!.docs.length;
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

              return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('daily_quest_status')
                      .where('lastCompleted', isEqualTo: today)
                      .snapshots(),
                  builder: (context, statusSnapshot) {
                    final completedCount = statusSnapshot.hasData ? statusSnapshot.data!.docs.length : 0;
                    final double progress = totalDailies > 0 ? completedCount / totalDailies : 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Today's Progress", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                                backgroundColor: Colors.grey.shade700,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text("$completedCount / $totalDailies", style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text("Daily quests completed", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    );
                  }
              );
            }
        ),
      ),
    );
  }

  Widget _buildActiveQuestsList(BuildContext context, String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('quests')
          .where('completed', isEqualTo: false)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return Card(
              color: const Color(0xFF16213E).withOpacity(0.5),
              child: const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                      child: Text("No active quests. Visit the Quest Log to add one!",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, height: 1.5))
                  )
              )
          );
        }
        final quests = snapshot.data!.docs;
        return Column(
          children: quests.map((doc) {
            final quest = doc.data() as Map<String, dynamic>;
            List<String> rewards = [];
            final totalExp = (quest['totalExpReward'] ?? 0).toInt();
            final goldReward = (quest['goldReward'] ?? 0).toInt();
            final statReward = quest['statReward'] as Map<String, dynamic>? ?? {};

            if (totalExp > 0) rewards.add("+$totalExp EXP");
            if (goldReward > 0) rewards.add("+$goldReward Gold");
            if (statReward.isNotEmpty) rewards.add("+${statReward.values.first} ${statReward.keys.first}");
            final rewardString = rewards.join(' • ');

            return Card(
              color: const Color(0xFF16213E),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.yellowAccent),
                title: Text(quest['title'] ?? 'Quest', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: rewardString.isNotEmpty ? Text(rewardString, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)) : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}