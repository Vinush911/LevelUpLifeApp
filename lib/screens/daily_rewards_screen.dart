import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import 'dart:async'; // Required for the countdown timer

class DailyRewardsScreen extends StatefulWidget {
  final String uid;
  const DailyRewardsScreen({super.key, required this.uid});

  @override
  State<DailyRewardsScreen> createState() => _DailyRewardsScreenState();
}

class _DailyRewardsScreenState extends State<DailyRewardsScreen> {
  // --- DEFINE THE 7-DAY REWARDS ---
  final List<Map<String, dynamic>> _rewards = [
    {'day': 1, 'type': 'gold', 'amount': 100},
    {'day': 2, 'type': 'shards', 'amount': 5},
    {'day': 3, 'type': 'gold', 'amount': 250},
    {'day': 4, 'type': 'shards', 'amount': 10},
    {'day': 5, 'type': 'gold', 'amount': 500},
    {'day': 6, 'type': 'shards', 'amount': 20},
    {'day': 7, 'type': 'gold', 'amount': 1000}, // Big final reward
  ];

  bool _isClaiming = false;
  Timer? _timer;
  Duration _timeUntilNextReward = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- NEW: Starts a countdown timer ---
  void _startTimer(DateTime lastLogin) {
    _timer?.cancel();
    final nextRewardTime = DateTime(lastLogin.year, lastLogin.month, lastLogin.day).add(const Duration(days: 1));

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (now.isAfter(nextRewardTime)) {
        if(mounted) {
          setState(() => _timeUntilNextReward = Duration.zero);
        }
        timer.cancel();
      } else {
        if(mounted){
          setState(() => _timeUntilNextReward = nextRewardTime.difference(now));
        }
      }
    });
  }

  Future<void> _claimReward(User user, Map<String, dynamic> reward, bool shouldResetStreak) async {
    setState(() => _isClaiming = true);
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.uid);

    try {
      final rewardType = reward['type'];
      final rewardAmount = (reward['amount'] as num).toInt();

      if (shouldResetStreak) {
        user.loginStreak = 0;
      }

      if (rewardType == 'gold') {
        user.gold += rewardAmount;
      } else if (rewardType == 'shards') {
        user.gachaShards += rewardAmount;
      }

      user.loginStreak++;
      user.lastLogin = Timestamp.now();

      await userRef.update(user.toMap());

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You claimed $rewardAmount $rewardType!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error claiming reward: $e");
    } finally {
      if(mounted) {
        setState(() => _isClaiming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Login Rewards"),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF0F3460), const Color(0xFF1A1A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final user = User.fromFirestore(snapshot.data);

            final now = DateTime.now();
            final lastLoginDate = user.lastLogin.toDate();
            final isSameDay = now.year == lastLoginDate.year &&
                now.month == lastLoginDate.month &&
                now.day == lastLoginDate.day;

            final yesterday = now.subtract(const Duration(days: 1));
            final isConsecutiveDay = lastLoginDate.year == yesterday.year &&
                lastLoginDate.month == yesterday.month &&
                lastLoginDate.day == yesterday.day;

            final bool shouldResetStreak = !isSameDay && !isConsecutiveDay;
            final canClaim = !_isClaiming && !isSameDay;
            int displayStreak = shouldResetStreak ? 0 : user.loginStreak;
            final currentStreak = displayStreak % 7;

            if (isSameDay) {
              _startTimer(lastLoginDate);
            } else {
              _timer?.cancel();
              _timeUntilNextReward = Duration.zero;
            }

            int todayRewardIndex = currentStreak;
            if (todayRewardIndex >= _rewards.length) {
              todayRewardIndex = 0; // Failsafe
            }

            final todayReward = _rewards[todayRewardIndex];

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildTodayRewardCard(
                  reward: todayReward,
                  canClaim: canClaim,
                  isClaimed: isSameDay,
                  onClaim: () => _claimReward(user, todayReward, shouldResetStreak),
                  timeUntilNext: _timeUntilNextReward,
                ),
                const SizedBox(height: 24),
                _buildSectionHeader("Upcoming Rewards"),
                const SizedBox(height: 12),
                _buildUpcomingRewardsList(currentStreak),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTodayRewardCard({
    required Map<String, dynamic> reward,
    required bool canClaim,
    required bool isClaimed,
    required VoidCallback onClaim,
    required Duration timeUntilNext,
  }) {
    final day = reward['day'];
    final type = reward['type'];
    final amount = reward['amount'];
    final isGold = type == 'gold';
    final icon = isGold ? Icons.monetization_on : Icons.diamond;
    final color = isGold ? Colors.amber : Colors.cyanAccent;
    final formattedTime = '${timeUntilNext.inHours.toString().padLeft(2, '0')}:${(timeUntilNext.inMinutes % 60).toString().padLeft(2, '0')}:${(timeUntilNext.inSeconds % 60).toString().padLeft(2, '0')}';

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.6), color.withOpacity(0.3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Text("Day $day Reward", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Icon(icon, color: Colors.white, size: 60),
            const SizedBox(height: 8),
            Text(amount.toString(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(isGold ? "Gold" : "Shards", style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
            const SizedBox(height: 24),
            if (isClaimed)
              Column(
                children: [
                  const Chip(
                    label: Text("CLAIMED TODAY", style: TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.greenAccent,
                    labelStyle: TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Text("Next reward in: $formattedTime", style: const TextStyle(color: Colors.white70)),
                ],
              )
            else if (canClaim)
              ElevatedButton(
                onPressed: _isClaiming ? null : onClaim,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  backgroundColor: color,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: _isClaiming ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black)) : const Text("Claim Now"),
              )
            else
              const SizedBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70));
  }

  Widget _buildUpcomingRewardsList(int currentStreak) {
    final upcoming = _rewards.where((r) => r['day']! > currentStreak + 1).toList();
    if (upcoming.isEmpty) {
      return const Center(child: Text("Final reward claimed! Resets next week.", style: TextStyle(color: Colors.grey)));
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: upcoming.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final reward = upcoming[index];
          final day = reward['day'];
          final type = reward['type'];
          final amount = reward['amount'];
          final isGold = type == 'gold';
          final icon = isGold ? Icons.monetization_on : Icons.diamond;
          final color = isGold ? Colors.amber : Colors.cyanAccent;

          return AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E).withOpacity(0.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Day $day", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                  const Spacer(),
                  Icon(icon, color: color.withOpacity(0.8), size: 30),
                  const SizedBox(height: 4),
                  Text(amount.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
                  const Spacer(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

