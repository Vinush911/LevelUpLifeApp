import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import 'quest_screen.dart';
import 'profile_screen.dart';
import 'achievements_screen.dart';
import 'skill_tree_screen.dart';
import 'shop_screen.dart';
import 'leaderboard_screen.dart';
import 'friends_screen.dart';
import 'gacha_screen.dart';
import 'inventory_screen.dart';
import 'daily_rewards_screen.dart';
import 'guilds_screen.dart';
import 'epic_quests_screen.dart';
import 'adventurers_log_screen.dart';
import 'admin_panel_screen.dart';
import 'wallet_screen.dart';
import 'ledger_screen.dart'; // 🪙 NEW: Imported Ledger Screen
// --- NEW: Import new screens ---
import 'diary_screen.dart';
import 'notes_screen.dart';
import 'timetable_screen.dart'; // <<<--- ADD THIS IMPORT
import '../models/user.dart' as app_user;

class HomeScreen extends StatelessWidget {
  final String uid;
  const HomeScreen({super.key, required this.uid});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // Close the drawer
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () => _showLogoutConfirmation(context),
          )
        ],
      ),
      body: DashboardScreen(uid: uid),
      drawer: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          bool isAdmin = false;
          if (snapshot.hasData && snapshot.data!.exists) {
            final user = app_user.User.fromFirestore(snapshot.data);
            isAdmin = user.isAdmin ?? false;
          }

          return Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: Color(0xFF0F3460)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield, color: Colors.purpleAccent, size: 48),
                      SizedBox(height: 8),
                      Text('QuestForge', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                _buildDrawerItem(context, icon: Icons.dashboard, title: 'Dashboard', screen: this),
                // --- ADDED TIMETABLE HERE ---
                _buildDrawerItem(context, icon: Icons.calendar_month, title: 'Timetable', screen: TimetableScreen(uid: uid)),
                _buildDrawerItem(context, icon: Icons.calendar_today, title: 'Daily Rewards', screen: DailyRewardsScreen(uid: uid)),
                _buildDrawerItem(context, icon: Icons.auto_stories, title: 'Epic Quests', screen: EpicQuestsScreen(uid: uid)),
                _buildDrawerItem(context, icon: Icons.list_alt, title: 'Quest Log', screen: QuestScreen(uid: uid)),
                // --- NEW: Add Diary and Notes to Drawer ---
                _buildDrawerItem(context, icon: Icons.book, title: 'Diary', screen: DiaryScreen(uid: uid)),
                _buildDrawerItem(context, icon: Icons.note_alt, title: 'Notes', screen: NotesScreen(uid: uid)),
                const Divider(),
                _buildDrawerItem(context, icon: Icons.person, title: 'Character Sheet', screen: ProfileScreen(uid: uid)),
                _buildDrawerItem(context, icon: Icons.inventory_2, title: 'Inventory', screen: InventoryScreen(uid: uid)),
                _buildDrawerItem(context, icon: Icons.wallet, title: 'Wallet', screen: WalletScreen(uid: uid)),
                // 🪙 ADDED LEDGER HERE
                _buildDrawerItem(context, icon: Icons.menu_book, title: "Merchant's Ledger", screen: const LedgerScreen()),
                _buildDrawerItem(context, icon: Icons.history, title: "Adventurer's Log", screen: AdventurersLogScreen(uid: uid)),
                _buildDrawerItem(context, icon: Icons.people, title: 'Friends', screen: FriendsScreen(uid: uid)),
                _buildDrawerItem(context, icon: Icons.shield, title: 'Guilds', screen: GuildsScreen(uid: uid)),
                const Divider(),
                _buildDrawerItem(context, icon: Icons.emoji_events, title: 'Achievements', screen: AchievementsScreen(uid: uid)),
                _buildDrawerItem(context, icon: Icons.account_tree, title: 'Skill Tree', screen: SkillTreeScreen(uid: uid)),
                _buildDrawerItem(context, icon: Icons.storefront, title: 'Shop', screen: ShopScreen(uid: uid)),
                _buildDrawerItem(context, icon: Icons.card_giftcard, title: 'Gacha', screen: GachaScreen(uid: uid)),
                _buildDrawerItem(context, icon: Icons.leaderboard, title: 'Leaderboards', screen: const LeaderboardScreen()),
                if (isAdmin) ...[
                  const Divider(),
                  _buildDrawerItem(context, icon: Icons.admin_panel_settings, title: 'Admin Panel', screen: const AdminPanelScreen()),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String title, required Widget screen}) {
    final isDashboard = screen is HomeScreen;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        if (isDashboard) {
          Navigator.pop(context);
        } else {
          _navigateTo(context, screen);
        }
      },
    );
  }
}