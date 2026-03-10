import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// Models
import '../models/user.dart' as app_user; // Aliased to prevent clash with FirebaseAuth User
import '../models/avatars.dart';

// Services
import '../services/notification_service.dart';

// Screens for Quick Travel
import 'wallet_screen.dart';
import 'ledger_screen.dart';
import 'timetable_screen.dart';
import 'diary_screen.dart';
import 'notes_screen.dart';
import 'adventurers_log_screen.dart';
import 'daily_rewards_screen.dart';
import 'quest_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String uid;
  const DashboardScreen({super.key, required this.uid});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _energyTimer;
  String _energyCountdown = "00:00";
  DateTime? _lastRechargeTracker;

  // Cache the stream so it doesn't recreate every second!
  late final Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();

    // Initialize the stream ONCE
    _userStream = FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots();

    // Request notification permissions as soon as the dashboard loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.instance.requestPermissions();

      // 🗡️ Schedule the immersive RPG background notifications
      await NotificationService.instance.scheduleInactivityReminder();
      await NotificationService.instance.scheduleDailyQuestReset();
      await NotificationService.instance.scheduleStreakWarning();
    });
  }

  @override
  void dispose() {
    _energyTimer?.cancel();
    super.dispose();
  }

  void _startEnergyTimer(app_user.User user) {
    if (user.currentEnergy >= user.maxEnergy) {
      _energyTimer?.cancel();
      if (mounted && _energyCountdown != "Full") {
        setState(() => _energyCountdown = "Full");
      }
      return;
    }

    final lastRecharge = user.lastEnergyRecharge.toDate();

    if (_energyTimer != null && _energyTimer!.isActive && _lastRechargeTracker == lastRecharge) {
      return;
    }

    _lastRechargeTracker = lastRecharge;
    _energyTimer?.cancel();

    final pointsNeeded = user.maxEnergy - user.currentEnergy;
    final currentCyclePassed = DateTime.now().difference(lastRecharge).inSeconds % 300;
    final secondsToFull = (pointsNeeded * 300) - currentCyclePassed;
    final fullTime = DateTime.now().add(Duration(seconds: secondsToFull));
    NotificationService.instance.scheduleEnergyFullNotification(fullTime);

    _energyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final totalDiff = now.difference(lastRecharge);
      final pointsToRecover = (totalDiff.inSeconds / 300).floor();

      if (user.currentEnergy + pointsToRecover >= user.maxEnergy) {
        setState(() => _energyCountdown = "Full");
        timer.cancel();
      } else {
        final cyclePassed = totalDiff.inSeconds % 300;
        final secondsLeft = 300 - cyclePassed;
        final minutes = (secondsLeft / 60).floor();
        final seconds = secondsLeft % 60;

        final newCountdown = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

        if (_energyCountdown != newCountdown) {
          setState(() => _energyCountdown = newCountdown);
        }
      }
    });
  }

  void _navigate(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  String _getDynamicGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return "The night is still young";
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    if (hour < 21) return "Good evening";
    return "Rest well";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Tavern Hub", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.amber),
            tooltip: "Town Crier (Alerts)",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Town Crier: All is quiet. Your guild alerts are active! 📜"),
                  backgroundColor: Colors.purpleAccent,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard, color: Colors.amber),
            tooltip: "Daily Rewards",
            onPressed: () => _navigate(DailyRewardsScreen(uid: widget.uid)),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F3460), Color(0xFF1A1A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _userStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text("Player data not found."));
            }

            final user = app_user.User.fromFirestore(snapshot.data!);
            user.regenerateEnergy();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _startEnergyTimer(user);
            });

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- DYNAMIC GREETING ---
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16, top: 8),
                    child: Text(
                      "${_getDynamicGreeting()}, ${user.name}!",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5
                      ),
                    ),
                  ),

                  _buildProfileCard(user),
                  const SizedBox(height: 32),

                  const Text("QUICK TRAVEL", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
                  const SizedBox(height: 16),
                  _buildQuickTravelGrid(),
                  const SizedBox(height: 32),

                  const Text("ACTIVE QUESTS", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
                  const SizedBox(height: 16),
                  _buildActiveQuests(),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileCard(app_user.User user) {
    final double energyProgress = user.maxEnergy > 0 ? (user.currentEnergy / user.maxEnergy) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.purpleAccent.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10)
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 10),
                    ]
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                  backgroundImage: NetworkImage(user.avatarUrl ?? avatarUrls[0]),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Lv. ${user.level}",
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                    ),
                    Text(
                      user.title,
                      style: TextStyle(color: Colors.purpleAccent.shade100, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCurrencyBadge(Icons.monetization_on, user.gold.toString(), Colors.amber),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildCurrencyBadge(Icons.diamond, user.gachaShards.toString(), Colors.cyanAccent),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildCurrencyBadge(Icons.bolt, "${user.currentEnergy}/${user.maxEnergy}", Colors.yellowAccent),
            ],
          ),
          const SizedBox(height: 20),
          // Energy Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Energy", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(_energyCountdown, style: const TextStyle(color: Colors.yellowAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: energyProgress.isFinite ? energyProgress.clamp(0.0, 1.0) : 0.0,
                  minHeight: 10,
                  backgroundColor: Colors.black45,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.yellowAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyBadge(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildQuickTravelGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        _buildActionCard(Icons.account_balance_wallet, "Wallet", Colors.greenAccent),
        _buildActionCard(Icons.menu_book_rounded, "Ledger", Colors.amber),
        _buildActionCard(Icons.calendar_month, "Timetable", Colors.lightBlueAccent),
        _buildActionCard(Icons.book, "Diary", Colors.pinkAccent),
        _buildActionCard(Icons.edit_document, "Notes", Colors.orangeAccent),
        _buildActionCard(Icons.local_fire_department, "Log", Colors.redAccent),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {
        if (label == "Wallet") _navigate(WalletScreen(uid: widget.uid));
        if (label == "Ledger") _navigate(const LedgerScreen());
        if (label == "Timetable") _navigate(TimetableScreen(uid: widget.uid));
        if (label == "Diary") _navigate(DiaryScreen(uid: widget.uid));
        if (label == "Notes") _navigate(NotesScreen(uid: widget.uid));
        if (label == "Log") _navigate(AdventurersLogScreen(uid: widget.uid));
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 34),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveQuests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('quests')
          .where('completed', isEqualTo: false)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final quests = snapshot.data!.docs;

        if (quests.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 16),
                Text("No active quests.", style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: () => _navigate(QuestScreen(uid: widget.uid)),
                    child: const Text("Go to Quest Board", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 16))
                )
              ],
            ),
          );
        }

        return Column(
          children: quests.map((doc) {
            final quest = doc.data() as Map<String, dynamic>;
            List<String> rewards = [];
            final totalExp = (quest['totalExpReward'] as num? ?? 0).toInt();
            final goldReward = (quest['goldReward'] as num? ?? 0).toInt();

            if (totalExp > 0) rewards.add("+$totalExp EXP");
            if (goldReward > 0) rewards.add("+$goldReward Gold");
            final rewardString = rewards.join(' • ');

            return Card(
              color: const Color(0xFF16213E),
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.purpleAccent.withOpacity(0.3), width: 1.5),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber.withOpacity(0.5))
                  ),
                  child: const Icon(Icons.star, color: Colors.amber, size: 24),
                ),
                title: Text(
                    quest['title'] ?? 'Unknown Quest',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                ),
                subtitle: rewardString.isNotEmpty
                    ? Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(rewardString, style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600)),
                )
                    : null,
                trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white54),
                onTap: () => _navigate(QuestScreen(uid: widget.uid)),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}