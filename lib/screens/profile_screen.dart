import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/item.dart';
import '../models/avatars.dart';
import '../widgets/stat_chart_painter.dart';
import 'dart:async';

class ProfileScreen extends StatefulWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- Function to assign a stat point ---
  Future<void> _assignStatPoint(String stat) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.uid);

    try {
      await firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw Exception("User not found.");

        final user = User.fromFirestore(userDoc);

        if (user.unassignedStatPoints > 0) {
          user.unassignedStatPoints -= 1;
          user.stats[stat] = (user.stats[stat] ?? 0) + 1;
          transaction.update(userRef, {
            'unassignedStatPoints': user.unassignedStatPoints,
            'stats': user.stats,
          });
        } else {
          throw Exception("No unassigned stat points available.");
        }
      });
      // Play a small sound or give subtle feedback here if desired
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _resetCharacter(User currentUser) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Text("Reset Your Character?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "This will reset your level, EXP, gold, items, skills, and stats to their default values.\n\nYour friends list and admin status will NOT be affected. This action cannot be undone.",
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
            ),
            child: const Text("Reset", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.uid);

    try {
      final defaultData = {
        'name': 'Adventurer',
        'level': 1,
        'exp': 0.0,
        'title': 'Novice Adventurer',
        'stats': {'STR': 10, 'END': 10, 'DEX': 10, 'INT': 10, 'WIS': 10, 'CHA': 10},
        'unassignedStatPoints': 0,
        'unlockedAchievements': {},
        'unlockedSkills': {},
        'gold': 50,
        'gachaShards': 0,
        'purchasedItems': [],
        'equippedItems': {},
        'avatarUrl': avatarUrls.first,
        'userClass': null,
        'gachaPityCounter': 0,
        'loginStreak': 0,
        'lastLogin': Timestamp.fromMillisecondsSinceEpoch(0),
        'guildId': null,
        'currentEnergy': 100,
        'maxEnergy': 100,
        'lastEnergyRecharge': Timestamp.now(),
        'statusMessage': null,
        'pvpWins': 0,
        'pvpLosses': 0,
        'friends': currentUser.friends,
        'friendRequestsSent': currentUser.friendRequestsSent,
        'friendRequestsReceived': currentUser.friendRequestsReceived,
        'isAdmin': currentUser.isAdmin ?? false,
        'lastOnline': Timestamp.now(),
      };

      if (currentUser.guildId != null) {
        final guildRef = firestore.collection('guilds').doc(currentUser.guildId!);
        await guildRef.update({
          'members': FieldValue.arrayRemove([widget.uid])
        });
      }

      await userRef.set(defaultData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Character has been reset successfully.", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("An error occurred: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAvatarSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5)),
          ),
          title: const Text("Choose Your Avatar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: avatarUrls.length,
              itemBuilder: (context, index) {
                final avatarUrl = avatarUrls[index];
                return GestureDetector(
                  onTap: () async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.uid)
                        .update({'avatarUrl': avatarUrl});
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber.withOpacity(0.6), width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 8),
                        ]
                    ),
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(avatarUrl),
                      backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            )
          ],
        );
      },
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName) {
    final nameController = TextEditingController(text: currentName);
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5)),
          ),
          title: const Text("Change Your Name", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "New Name",
              labelStyle: TextStyle(color: Colors.grey.shade400),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purple.shade200)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.black,
              ),
              child: const Text("Update", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != currentName) {
                  await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'name': newName});
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Character Sheet", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
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
          stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
            }
            final user = User.fromFirestore(userSnapshot.data);

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('shop_items').snapshots(),
              builder: (context, itemSnapshot) {
                if (!itemSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                }
                final allItems = itemSnapshot.data!.docs.map((doc) => Item.fromFirestore(doc)).toList();
                final finalStats = _calculateFinalStats(user, allItems);
                final baseStats = user.stats;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserHeader(user, context),
                      const SizedBox(height: 24),

                      // --- GLOWING STAT POINT BANNER ---
                      if (user.unassignedStatPoints > 0)
                        _buildStatPointHeader(user.unassignedStatPoints),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 250,
                              child: CustomPaint(
                                painter: StatChartPainter(stats: finalStats),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _buildCoreAttributes(baseStats, finalStats, user.unassignedStatPoints > 0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildSectionHeader("Equipment"),
                      const SizedBox(height: 12),
                      _buildEquipmentSlots(user, allItems),
                      const SizedBox(height: 32),
                      _buildSectionHeader("Unlocked Skills"),
                      const SizedBox(height: 12),
                      _buildSkillsList(user),
                      const SizedBox(height: 32),
                      _buildSectionHeader("Unlocked Achievements"),
                      const SizedBox(height: 12),
                      _buildAchievementsList(user),
                      const Divider(height: 48, color: Colors.white24),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () => _resetCharacter(user),
                          icon: const Icon(Icons.warning_amber_rounded),
                          label: const Text("Reset Character", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // --- GLOWING STAT POINT HEADER ---
  Widget _buildStatPointHeader(int points) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.greenAccent.withOpacity(0.15), blurRadius: 15, spreadRadius: 2),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.greenAccent, size: 28),
          const SizedBox(width: 12),
          Text(
            "$points Stat Points Available!",
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.1
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculateFinalStats(User user, List<Item> allItems) {
    Map<String, int> finalStats = Map.from(user.stats);

    user.equippedItems.forEach((slot, itemId) {
      final item = allItems.firstWhere((i) => i.id == itemId, orElse: () => Item(id: '', name: '', description: '', price: 0, type: ItemType.consumable, effects: {}));
      if (item.effects.containsKey('stat')) {
        final stat = item.effects['stat'] as String;
        final value = (item.effects['value'] as num? ?? 0).toInt();
        finalStats[stat] = ((finalStats[stat] ?? 0) + value);
      }
    });

    return finalStats;
  }

  // --- PREMIUM GLASSMORPHISM USER HEADER ---
  Widget _buildUserHeader(User user, BuildContext context) {
    final double progress = user.nextLevelExp() > 0 ? user.exp / user.nextLevelExp() : 0.0;
    final imageUrl = user.avatarUrl ?? avatarUrls.first;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showAvatarSelectionDialog(context),
                child: Container(
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 10),
                      ]
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                    backgroundImage: NetworkImage(imageUrl),
                    onBackgroundImageError: (_, __) {},
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _showEditNameDialog(context, user.name),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(Icons.edit, color: Colors.grey.shade400, size: 18),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                        user.title,
                        style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.purple.shade200, fontWeight: FontWeight.w500)
                    ),
                    if (user.userClass != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                          ),
                          child: Text(
                            user.userClass!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.cyanAccent, letterSpacing: 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(user.gold.toString(), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('LVL ${user.level}', style: const TextStyle(fontSize: 14, color: Colors.amber, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.black45,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${user.exp.toStringAsFixed(0)} / ${user.nextLevelExp().toStringAsFixed(0)} EXP', style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.arrow_right, color: Colors.purpleAccent),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreAttributes(Map<String, int> baseStats, Map<String, int> finalStats, bool canAssignPoints) {
    final statOrder = ['STR', 'DEX', 'END', 'INT', 'WIS', 'CHA'];
    final Map<String, IconData> statIcons = {
      'STR': Icons.fitness_center,
      'DEX': Icons.flash_on,
      'END': Icons.shield,
      'INT': Icons.psychology,
      'WIS': Icons.self_improvement,
      'CHA': Icons.star,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ATTRIBUTES", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
          const Divider(color: Colors.white24, height: 24),
          ...statOrder.map((stat) {
            final baseValue = baseStats[stat] ?? 0;
            final finalValue = finalStats[stat] ?? 0;
            final bonus = finalValue - baseValue;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Icon(statIcons[stat], color: Colors.purpleAccent.shade100, size: 18),
                  const SizedBox(width: 8),
                  SizedBox(width: 35, child: Text(stat, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13))),
                  Expanded(child: Text(finalValue.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                  if (bonus > 0)
                    Text("(+$bonus)", style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  // --- Add '+' button if points are available ---
                  if (canAssignPoints)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      height: 24,
                      width: 24,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.add, color: Colors.greenAccent, size: 18),
                        onPressed: () => _assignStatPoint(stat),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildEquipmentSlots(User user, List<Item> allItems) {
    final Map<EquipmentSlot, IconData> slotIcons = {
      EquipmentSlot.amulet: Icons.shield,
      EquipmentSlot.boots: Icons.directions_run,
    };

    return Column(
      children: EquipmentSlot.values.map((slot) {
        final itemId = user.equippedItems[slot.name];
        final item = itemId != null ? allItems.firstWhere((i) => i.id == itemId, orElse: () => Item(id: '', name: 'Empty', description: '', price: 0, type: ItemType.consumable, effects: {})) : null;
        final bool isEquipped = item != null;

        return Card(
          color: const Color(0xFF16213E).withOpacity(0.8),
          elevation: isEquipped ? 4 : 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isEquipped ? Colors.purpleAccent.withOpacity(0.5) : Colors.white10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: isEquipped ? Colors.purpleAccent.withOpacity(0.2) : Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isEquipped ? Colors.purpleAccent.withOpacity(0.5) : Colors.transparent)
              ),
              child: Icon(
                slotIcons[slot] ?? Icons.help_outline,
                color: isEquipped ? Colors.purpleAccent.shade100 : Colors.grey,
              ),
            ),
            title: Text(
              item?.name ?? 'Empty ${slot.name} slot',
              style: TextStyle(
                color: isEquipped ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: isEquipped
                ? Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '+${(item.effects['value'] as num? ?? 0).toInt()} ${item.effects['stat']}',
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            )
                : Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text("Nothing equipped", style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillsList(User user) {
    if (user.unlockedSkills.isEmpty) {
      return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Icon(Icons.auto_awesome, color: Colors.grey.withOpacity(0.5), size: 40),
              const SizedBox(height: 12),
              const Text("No skills unlocked yet.", style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          )
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
      ),
      child: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('skills').get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final allSkillsMap = { for (var doc in snapshot.data!.docs) doc.id: doc.data() as Map<String, dynamic> };
            return Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: user.unlockedSkills.entries.map((entry) {
                final skillData = allSkillsMap[entry.key];
                if (skillData == null) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_purple500, color: Colors.cyanAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                          "${skillData['title']} ",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                      Text(
                          "Lv.${entry.value}",
                          style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w900)
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
    );
  }

  Widget _buildAchievementsList(User user) {
    if (user.unlockedAchievements.isEmpty) {
      return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Icon(Icons.emoji_events_outlined, color: Colors.grey.withOpacity(0.5), size: 40),
              const SizedBox(height: 12),
              const Text("No achievements unlocked yet.", style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          )
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('achievements').get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final allAchievementsMap = { for (var doc in snapshot.data!.docs) doc.id: doc.data() as Map<String, dynamic> };
          return Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children: user.unlockedAchievements.keys.map((key) {
              final achievementData = allAchievementsMap[key];
              if (achievementData == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Text(
                        achievementData['title'] ?? key,
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}