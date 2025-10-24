import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

// --- MODIFIED: Converted to a StatefulWidget ---
class SkillTreeScreen extends StatefulWidget {
  final String uid;
  const SkillTreeScreen({super.key, required this.uid});

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends State<SkillTreeScreen> {
  bool _isUpgrading = false;

  // --- NEW: Function to handle the skill upgrade logic ---
  Future<void> _upgradeSkill(User user, DocumentSnapshot skillDoc) async {
    setState(() => _isUpgrading = true);
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.uid);
    final skillData = skillDoc.data() as Map<String, dynamic>;
    final skillId = skillDoc.id;

    final currentLevel = user.unlockedSkills[skillId] ?? 1;
    final maxLevel = (skillData['maxLevel'] as num? ?? 1).toInt();
    final costGold = ((skillData['upgradeCostGold'] as num? ?? 0) * currentLevel).toInt();
    final costShards = ((skillData['upgradeCostShards'] as num? ?? 0) * currentLevel).toInt();

    if (currentLevel >= maxLevel || user.gold < costGold || user.gachaShards < costShards) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot upgrade. Check resources or max level."), backgroundColor: Colors.red),
      );
      setState(() => _isUpgrading = false);
      return;
    }

    try {
      user.gold -= costGold;
      user.gachaShards -= costShards;
      user.unlockedSkills[skillId] = currentLevel + 1;

      await userRef.update({
        'gold': user.gold,
        'gachaShards': user.gachaShards,
        'unlockedSkills': user.unlockedSkills,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${skillData['title']} upgraded to Level ${currentLevel + 1}!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error upgrading skill: $e");
    } finally {
      if(mounted) {
        setState(() => _isUpgrading = false);
      }
    }
  }

  // --- NEW: Confirmation dialog ---
  void _showUpgradeDialog(User user, DocumentSnapshot skillDoc) {
    final skillData = skillDoc.data() as Map<String, dynamic>;
    final currentLevel = user.unlockedSkills[skillDoc.id] ?? 1;
    final costGold = ((skillData['upgradeCostGold'] as num? ?? 0) * currentLevel).toInt();
    final costShards = ((skillData['upgradeCostShards'] as num? ?? 0) * currentLevel).toInt();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Upgrade ${skillData['title']}?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Upgrade to Level ${currentLevel + 1}."),
            const SizedBox(height: 16),
            const Text("Cost:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("$costGold Gold"),
            Text("$costShards Shards"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: _isUpgrading ? null : () {
              Navigator.pop(context);
              _upgradeSkill(user, skillDoc);
            },
            child: _isUpgrading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator()) : const Text("Confirm"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Skill Tree"),
      ),
      backgroundColor: const Color(0xFF1A1A2E),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('skills').snapshots(),
        builder: (context, skillSnapshot) {
          if (!skillSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final skills = skillSnapshot.data!.docs;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }
              final user = User.fromFirestore(userSnapshot.data);

              return Column(
                children: [
                  // --- NEW: Currency Display Header ---
                  _buildCurrencyHeader(user),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: skills.length,
                      itemBuilder: (context, index) {
                        final skillDoc = skills[index];
                        final skillData = skillDoc.data() as Map<String, dynamic>;
                        final skillId = skillDoc.id;
                        final currentLevel = user.unlockedSkills[skillId] ?? 0;
                        final isUnlocked = currentLevel > 0;

                        // --- NEW: Calculate upgrade costs and conditions ---
                        final maxLevel = (skillData['maxLevel'] as num? ?? 1).toInt();
                        final costGold = ((skillData['upgradeCostGold'] as num? ?? 0) * currentLevel).toInt();
                        final costShards = ((skillData['upgradeCostShards'] as num? ?? 0) * currentLevel).toInt();
                        final canAfford = user.gold >= costGold && user.gachaShards >= costShards;
                        final isMaxLevel = currentLevel >= maxLevel;

                        if (!isUnlocked) {
                          // Render a locked skill differently if you want
                          return Card(
                            color: Theme.of(context).cardColor.withOpacity(0.3),
                            child: ListTile(
                              leading: const Icon(Icons.lock, color: Colors.grey),
                              title: Text(skillData['title'] ?? 'Skill', style: const TextStyle(color: Colors.grey)),
                              subtitle: Text(skillData['description'] ?? '', style: const TextStyle(color: Colors.grey)),
                            ),
                          );
                        }

                        return Card(
                          color: const Color(0xFF16213E),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${skillData['title'] ?? 'Skill'} - LVL $currentLevel / $maxLevel",
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                                ),
                                const SizedBox(height: 4),
                                Text(skillData['description'] ?? '', style: TextStyle(color: Colors.grey.shade400)),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Next Upgrade Cost:", style: TextStyle(color: Colors.white70)),
                                        Text("$costGold Gold", style: TextStyle(color: user.gold >= costGold ? Colors.amber : Colors.redAccent)),
                                        Text("$costShards Shards", style: TextStyle(color: user.gachaShards >= costShards ? Colors.cyanAccent : Colors.redAccent)),
                                      ],
                                    ),
                                    ElevatedButton(
                                      onPressed: (isMaxLevel || !canAfford || _isUpgrading) ? null : () => _showUpgradeDialog(user, skillDoc),
                                      child: Text(isMaxLevel ? "Max Level" : "Upgrade"),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // --- NEW: Widget for displaying currency ---
  Widget _buildCurrencyHeader(User user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black.withOpacity(0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _currencyChip(
            icon: Icons.monetization_on,
            label: user.gold.toString(),
            color: Colors.amber,
          ),
          const SizedBox(width: 12),
          _currencyChip(
            icon: Icons.diamond,
            label: user.gachaShards.toString(),
            color: Colors.cyanAccent,
          ),
        ],
      ),
    );
  }

  Widget _currencyChip({required IconData icon, required String label, required Color color}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

