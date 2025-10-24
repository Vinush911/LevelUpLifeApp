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
  // --- NEW: Function to assign a stat point ---
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resetCharacter(User currentUser) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Your Character?"),
        content: const Text(
            "This will reset your level, EXP, gold, items, skills, and stats to their default values. \n\nYour friends list and admin status will NOT be affected. This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Reset"),
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
            content: Text("Character has been reset successfully."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("An error occurred: $e"),
            backgroundColor: Colors.red,
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
          title: const Text("Choose Your Avatar"),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
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
                    Navigator.pop(context);
                  },
                  child: CircleAvatar(
                    backgroundImage: NetworkImage(avatarUrl),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
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
          title: const Text("Change Your Name", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(labelText: "New Name", labelStyle: TextStyle(color: Colors.purple.shade200)),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              child: const Text("Update"),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != currentName) {
                  await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'name': newName});
                }
                Navigator.pop(context);
              },
            ),
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Character Sheet"),
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
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }
            final user = User.fromFirestore(userSnapshot.data);

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('shop_items').snapshots(),
              builder: (context, itemSnapshot) {
                if (!itemSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allItems = itemSnapshot.data!.docs.map((doc) => Item.fromFirestore(doc)).toList();
                final finalStats = _calculateFinalStats(user, allItems);
                final baseStats = user.stats;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserHeader(user, context),
                      const SizedBox(height: 24),
                      // --- NEW: Display for unassigned stat points ---
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
                      const SizedBox(height: 24),
                      _buildSectionHeader("Unlocked Skills"),
                      const SizedBox(height: 12),
                      _buildSkillsList(user),
                      const SizedBox(height: 24),
                      _buildSectionHeader("Unlocked Achievements"),
                      const SizedBox(height: 12),
                      _buildAchievementsList(user),
                      const Divider(height: 48),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () => _resetCharacter(user),
                          icon: const Icon(Icons.refresh),
                          label: const Text("Reset Character"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade900,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
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

  // --- NEW: Widget to display available stat points ---
  Widget _buildStatPointHeader(int points) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.greenAccent),
          const SizedBox(width: 8),
          Text(
            "$points Stat Points Available to Assign",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  Widget _buildUserHeader(User user, BuildContext context) {
    final double progress = user.nextLevelExp() > 0 ? user.exp / user.nextLevelExp() : 0.0;
    final imageUrl = user.avatarUrl ?? avatarUrls.first;

    return Card(
      color: const Color(0xFF16213E).withOpacity(0.5),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showAvatarSelectionDialog(context),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundImage: NetworkImage(imageUrl),
                    onBackgroundImageError: (_, __) {},
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
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _showEditNameDialog(context, user.name),
                            child: const Icon(Icons.edit, color: Colors.grey, size: 16),
                          )
                        ],
                      ),
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Chip(
                  avatar: const Icon(Icons.monetization_on, color: Colors.black, size: 18),
                  label: Text(user.gold.toString()),
                  backgroundColor: Colors.amber,
                  labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
                    backgroundColor: Colors.black.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text('${user.exp.toStringAsFixed(0)} / ${user.nextLevelExp().toStringAsFixed(0)} EXP', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1.2,
        ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Core Attributes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(color: Colors.purpleAccent),
          ...statOrder.map((stat) {
            final baseValue = baseStats[stat] ?? 0;
            final finalValue = finalStats[stat] ?? 0;
            final bonus = finalValue - baseValue;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  Icon(statIcons[stat], color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  SizedBox(width: 35, child: Text(stat, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  Expanded(child: Text(finalValue.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                  if (bonus > 0)
                    Text("(+$bonus)", style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  // --- NEW: Add '+' button if points are available ---
                  if (canAssignPoints)
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent, size: 20),
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
          elevation: isEquipped ? 4 : 1,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isEquipped ? Colors.purpleAccent.withOpacity(0.3) : Colors.black.withOpacity(0.3),
              child: Icon(
                slotIcons[slot] ?? Icons.help_outline,
                color: isEquipped ? Colors.purpleAccent : Colors.grey,
              ),
            ),
            title: Text(
              item?.name ?? 'Empty ${slot.name} slot',
              style: TextStyle(
                color: isEquipped ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: isEquipped
                ? Text(
              '+${(item.effects['value'] as num? ?? 0).toInt()} ${item.effects['stat']}',
              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w500),
            )
                : Text("Nothing equipped", style: TextStyle(color: Colors.grey.shade600)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillsList(User user) {
    if (user.unlockedSkills.isEmpty) {
      return const Center(
          child:
          Text("No skills unlocked yet.", style: TextStyle(color: Colors.grey)));
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('skills').get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final allSkillsMap = { for (var doc in snapshot.data!.docs) doc.id: doc.data() as Map<String, dynamic> };
            return Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: user.unlockedSkills.entries.map((entry) {
                final skillData = allSkillsMap[entry.key];
                if (skillData == null) return const SizedBox.shrink();
                return Chip(
                  avatar: const Icon(Icons.star, color: Colors.black, size: 16),
                  label: Text("${skillData['title']} - LVL ${entry.value}"),
                  backgroundColor: Colors.greenAccent,
                  labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                );
              }).toList(),
            );
          }),
    );
  }

  Widget _buildAchievementsList(User user) {
    if (user.unlockedAchievements.isEmpty) {
      return const Center(
          child: Text("No achievements unlocked yet.",
              style: TextStyle(color: Colors.grey)));
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('achievements').get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final allAchievementsMap = { for (var doc in snapshot.data!.docs) doc.id: doc.data() as Map<String, dynamic> };
          return Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: user.unlockedAchievements.keys.map((key) {
              final achievementData = allAchievementsMap[key];
              if (achievementData == null) return const SizedBox.shrink();
              return Chip(
                avatar: const Icon(Icons.emoji_events, color: Colors.black, size: 16),
                label: Text(achievementData['title'] ?? key),
                backgroundColor: Colors.amber,
                labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
