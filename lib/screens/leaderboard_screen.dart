import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

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
      appBar: AppBar(
        title: const Text("Leaderboards"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _leaderboardCategories
              .map((category) => Tab(text: category))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _leaderboardCategories.map((category) {
          return _LeaderboardListView(category: category);
        }).toList(),
      ),
    );
  }
}

class _LeaderboardListView extends StatelessWidget {
  final String category;

  const _LeaderboardListView({required this.category});

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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text("No user data available.",
                  style: TextStyle(color: Colors.white70)));
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final user = User.fromFirestore(userDoc);
            final rank = index + 1;

            String value;
            if (category == 'Level') {
              value = "Level ${user.level}";
            } else if (category == 'Gold') {
              value = "${user.gold} Gold";
            } else {
              value = "${user.stats[category]} $category";
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Text(
                  "#$rank",
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                title: Text(user.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                trailing: Text(value,
                    style: TextStyle(
                        color: Colors.purple.shade200, fontSize: 16)),
              ),
            );
          },
        );
      },
    );
  }
}
