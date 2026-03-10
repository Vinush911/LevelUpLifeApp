import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/avatars.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _leaderboardCategories = [
    'Level', 'Gold', 'STR', 'END', 'DEX', 'INT', 'WIS', 'CHA'
  ];

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _leaderboardCategories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Hall of Fame", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey.shade400,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
          tabs: _leaderboardCategories
              .map((category) => Tab(text: category.toUpperCase()))
              .toList(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F3460), Color(0xFF1A1A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: _leaderboardCategories.map((category) {
            return _LeaderboardListView(category: category);
          }).toList(),
        ),
      ),
    );
  }
}

class _LeaderboardListView extends StatelessWidget {
  final String category;

  const _LeaderboardListView({required this.category});

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey.shade300;
    if (rank == 3) return Colors.orange.shade400;
    return Colors.purpleAccent.shade100;
  }

  Widget _getRankBadge(int rank, Color rankColor) {
    return Container(
      width: 40,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (rank == 1)
            const Icon(Icons.workspace_premium, color: Colors.amber, size: 20)
          else if (rank <= 3)
            Icon(Icons.military_tech, color: rankColor, size: 20),

          Text(
            "#$rank",
            style: TextStyle(
              color: rankColor,
              fontSize: rank <= 3 ? 18 : 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String orderByField =
    (category == 'Level' || category == 'Gold') ? category.toLowerCase() : 'stats.$category';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy(orderByField, descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
        }
        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined, size: 60, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text(
                  "No champions found.",
                  style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          physics: const BouncingScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final user = User.fromFirestore(userDoc);
            final rank = index + 1;
            final rankColor = _getRankColor(rank);

            String valueText;
            String labelText;
            IconData statIcon;

            if (category == 'Level') {
              valueText = "${user.level}";
              labelText = "LVL";
              statIcon = Icons.star;
            } else if (category == 'Gold') {
              valueText = "${user.gold}";
              labelText = "Gold";
              statIcon = Icons.monetization_on;
            } else {
              valueText = "${user.stats[category]}";
              labelText = category;
              statIcon = Icons.fitness_center; // Generic stat icon

              if (category == 'INT' || category == 'WIS') statIcon = Icons.auto_awesome;
              if (category == 'DEX') statIcon = Icons.flash_on;
              if (category == 'END') statIcon = Icons.shield;
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E).withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: rankColor.withOpacity(rank <= 3 ? 0.6 : 0.2),
                    width: rank <= 3 ? 2 : 1
                ),
                boxShadow: rank <= 3 ? [
                  BoxShadow(color: rankColor.withOpacity(0.15), blurRadius: 10, spreadRadius: 1)
                ] : [],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _getRankBadge(rank, rankColor),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: rankColor.withOpacity(0.8), width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.purple.withOpacity(0.3),
                        backgroundImage: NetworkImage(user.avatarUrl ?? avatarUrls.first),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                subtitle: Text(
                  user.title,
                  style: TextStyle(
                      color: Colors.purple.shade200,
                      fontSize: 12,
                      fontStyle: FontStyle.italic
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: rankColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: rankColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statIcon, color: rankColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        valueText,
                        style: TextStyle(
                          color: rankColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}