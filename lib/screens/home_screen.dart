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
import 'ledger_screen.dart';
import 'diary_screen.dart';
import 'notes_screen.dart';
import 'timetable_screen.dart';
import '../models/user.dart' as app_user;
import '../models/avatars.dart';

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
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          title: const Text('Leave Realm?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
              'Are you sure you want to log out and leave your adventure behind?',
              style: TextStyle(color: Colors.white70)
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Main Menu", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
        // Removed the Appbar logout button to keep it clean, moved it to the drawer!
      ),
      body: DashboardScreen(uid: uid),
      drawer: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          bool isAdmin = false;
          app_user.User? user;

          if (snapshot.hasData && snapshot.data!.exists) {
            user = app_user.User.fromFirestore(snapshot.data);
            isAdmin = user.isAdmin ?? false;
          }

          return Drawer(
            backgroundColor: const Color(0xFF1A1A2E),
            child: Column(
              children: [
                // --- DYNAMIC PLAYER BANNER HEADER ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 50, bottom: 20, left: 16, right: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3460),
                    border: Border(bottom: BorderSide(color: Colors.purpleAccent.withOpacity(0.5), width: 2)),
                  ),
                  child: user == null
                      ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                      : Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 2),
                          boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 8)],
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.purple.withOpacity(0.2),
                          backgroundImage: NetworkImage(user.avatarUrl ?? avatarUrls.first),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Lv. ${user.level} ${user.title}",
                              style: TextStyle(color: Colors.purpleAccent.shade100, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- SCROLLABLE MENU ITEMS ---
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildSectionHeader("Tavern & Daily"),
                      _buildDrawerItem(context, icon: Icons.dashboard, title: 'Dashboard', screen: this),
                      _buildDrawerItem(context, icon: Icons.calendar_month, title: 'Timetable', screen: TimetableScreen(uid: uid)),
                      _buildDrawerItem(context, icon: Icons.calendar_today, title: 'Daily Rewards', screen: DailyRewardsScreen(uid: uid)),

                      const Divider(color: Colors.white12, height: 24, thickness: 1),
                      _buildSectionHeader("Quests & Adventures"),
                      _buildDrawerItem(context, icon: Icons.auto_stories, title: 'Epic Quests', screen: EpicQuestsScreen(uid: uid), iconColor: Colors.amber),
                      _buildDrawerItem(context, icon: Icons.list_alt, title: 'Quest Board', screen: QuestScreen(uid: uid), iconColor: Colors.amber),
                      _buildDrawerItem(context, icon: Icons.book, title: 'Adventurer\'s Diary', screen: DiaryScreen(uid: uid)),
                      _buildDrawerItem(context, icon: Icons.note_alt, title: 'Field Notes', screen: NotesScreen(uid: uid)),

                      const Divider(color: Colors.white12, height: 24, thickness: 1),
                      _buildSectionHeader("Character & Wealth"),
                      _buildDrawerItem(context, icon: Icons.person, title: 'Character Sheet', screen: ProfileScreen(uid: uid), iconColor: Colors.cyanAccent),
                      _buildDrawerItem(context, icon: Icons.inventory_2, title: 'Inventory', screen: InventoryScreen(uid: uid)),
                      _buildDrawerItem(context, icon: Icons.account_balance_wallet, title: 'Wallet', screen: WalletScreen(uid: uid), iconColor: Colors.greenAccent),
                      _buildDrawerItem(context, icon: Icons.menu_book, title: "Merchant's Ledger", screen: const LedgerScreen(), iconColor: Colors.greenAccent),
                      _buildDrawerItem(context, icon: Icons.history, title: "Adventurer's Log", screen: AdventurersLogScreen(uid: uid)),

                      const Divider(color: Colors.white12, height: 24, thickness: 1),
                      _buildSectionHeader("Progression"),
                      _buildDrawerItem(context, icon: Icons.emoji_events, title: 'Achievements', screen: AchievementsScreen(uid: uid), iconColor: Colors.amber),
                      _buildDrawerItem(context, icon: Icons.account_tree, title: 'Skill Tree', screen: SkillTreeScreen(uid: uid), iconColor: Colors.cyanAccent),
                      _buildDrawerItem(context, icon: Icons.leaderboard, title: 'Hall of Fame', screen: const LeaderboardScreen(), iconColor: Colors.amber),

                      const Divider(color: Colors.white12, height: 24, thickness: 1),
                      _buildSectionHeader("Multiplayer & Extras"),
                      _buildDrawerItem(context, icon: Icons.people, title: 'Friends list', screen: FriendsScreen(uid: uid)),
                      _buildDrawerItem(context, icon: Icons.shield, title: 'Guilds', screen: GuildsScreen(uid: uid)),
                      _buildDrawerItem(context, icon: Icons.storefront, title: 'Shop', screen: ShopScreen(uid: uid)),
                      _buildDrawerItem(context, icon: Icons.card_giftcard, title: 'Gacha Summons', screen: GachaScreen(uid: uid), iconColor: Colors.pinkAccent),

                      if (isAdmin) ...[
                        const Divider(color: Colors.redAccent, height: 24, thickness: 1),
                        _buildSectionHeader("System", color: Colors.redAccent),
                        _buildDrawerItem(context, icon: Icons.admin_panel_settings, title: 'Admin Panel', screen: AdminPanelScreen(), iconColor: Colors.redAccent),
                      ]
                    ],
                  ),
                ),

                // --- BOTTOM LOGOUT BUTTON ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F3460),
                    border: Border(top: BorderSide(color: Colors.white12, width: 1)),
                  ),
                  child: InkWell(
                    onTap: () => _showLogoutConfirmation(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.exit_to_app, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text("Leave Realm", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color color = Colors.grey}) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String title, required Widget screen, Color iconColor = Colors.purpleAccent}) {
    final isDashboard = screen is HomeScreen;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: Colors.purpleAccent.withOpacity(0.1),
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        onTap: () {
          if (isDashboard) {
            Navigator.pop(context);
          } else {
            _navigateTo(context, screen);
          }
        },
      ),
    );
  }
}