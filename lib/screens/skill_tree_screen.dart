import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class SkillTreeScreen extends StatefulWidget {
  final String uid;
  const SkillTreeScreen({super.key, required this.uid});

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends State<SkillTreeScreen> {
  bool _isUpgrading = false;

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
        const SnackBar(content: Text("Cannot upgrade. Check resources or max level.", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orangeAccent),
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
          SnackBar(
              content: Text("${skillData['title']} upgraded to Level ${currentLevel + 1}!", style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green
          ),
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

  void _showUpgradeDialog(User user, DocumentSnapshot skillDoc) {
    final skillData = skillDoc.data() as Map<String, dynamic>;
    final currentLevel = user.unlockedSkills[skillDoc.id] ?? 1;
    final costGold = ((skillData['upgradeCostGold'] as num? ?? 0) * currentLevel).toInt();
    final costShards = ((skillData['upgradeCostShards'] as num? ?? 0) * currentLevel).toInt();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.cyanAccent),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    "Upgrade ${skillData['title']}?",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
                )
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Increase power to Level ${currentLevel + 1}.", style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("REQUIRED RESOURCES:", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Text("$costGold Gold", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.diamond, color: Colors.cyanAccent, size: 18),
                      const SizedBox(width: 8),
                      Text("$costShards Shards", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isUpgrading ? null : () {
              Navigator.pop(context);
              _upgradeSkill(user, skillDoc);
            },
            child: _isUpgrading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Text("Confirm", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Skill Tree", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('skills').snapshots(),
          builder: (context, skillSnapshot) {
            if (!skillSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
            }
            final skills = skillSnapshot.data!.docs;

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                }
                final user = User.fromFirestore(userSnapshot.data);

                return Column(
                  children: [
                    _buildCurrencyHeader(user),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: 40),
                        itemCount: skills.length,
                        itemBuilder: (context, index) {
                          final skillDoc = skills[index];
                          final skillData = skillDoc.data() as Map<String, dynamic>;
                          final skillId = skillDoc.id;
                          final currentLevel = user.unlockedSkills[skillId] ?? 0;
                          final isUnlocked = currentLevel > 0;

                          final maxLevel = (skillData['maxLevel'] as num? ?? 1).toInt();
                          final costGold = ((skillData['upgradeCostGold'] as num? ?? 0) * currentLevel).toInt();
                          final costShards = ((skillData['upgradeCostShards'] as num? ?? 0) * currentLevel).toInt();
                          final canAfford = user.gold >= costGold && user.gachaShards >= costShards;
                          final isMaxLevel = currentLevel >= maxLevel;

                          if (!isUnlocked) {
                            return _buildLockedSkillCard(skillData);
                          }

                          return _buildUnlockedSkillCard(
                              user,
                              skillDoc,
                              skillData,
                              currentLevel,
                              maxLevel,
                              costGold,
                              costShards,
                              canAfford,
                              isMaxLevel
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
      ),
    );
  }

  Widget _buildLockedSkillCard(Map<String, dynamic> skillData) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline, color: Colors.grey, size: 24),
        ),
        title: Text(skillData['title'] ?? 'Unknown Skill', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(skillData['description'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildUnlockedSkillCard(User user, DocumentSnapshot skillDoc, Map<String, dynamic> skillData, int currentLevel, int maxLevel, int costGold, int costShards, bool canAfford, bool isMaxLevel) {

    // Max level styling vs normal unlocked styling
    final Color borderColor = isMaxLevel ? Colors.amber.withOpacity(0.6) : Colors.cyanAccent.withOpacity(0.4);
    final Color iconColor = isMaxLevel ? Colors.amber : Colors.cyanAccent;
    final Color bgColor = const Color(0xFF16213E).withOpacity(0.8);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          if (isMaxLevel) BoxShadow(color: Colors.amber.withOpacity(0.15), blurRadius: 15, spreadRadius: 1)
          else BoxShadow(color: Colors.cyanAccent.withOpacity(0.05), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.account_tree, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skillData['title'] ?? 'Skill',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isMaxLevel ? "MAX LEVEL ACHIEVED" : "LVL $currentLevel / $maxLevel",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isMaxLevel ? Colors.amber : Colors.cyanAccent,
                            letterSpacing: 1.5
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(skillData['description'] ?? '', style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.4)),
            const Divider(height: 24, color: Colors.white12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isMaxLevel)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("UPGRADE COST:", style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.monetization_on, color: user.gold >= costGold ? Colors.amber : Colors.redAccent, size: 14),
                          const SizedBox(width: 4),
                          Text("$costGold", style: TextStyle(color: user.gold >= costGold ? Colors.white : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 12),
                          Icon(Icons.diamond, color: user.gachaShards >= costShards ? Colors.cyanAccent : Colors.redAccent, size: 14),
                          const SizedBox(width: 4),
                          Text("$costShards", style: TextStyle(color: user.gachaShards >= costShards ? Colors.white : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ],
                  )
                else
                  const Text("Skill Mastered", style: TextStyle(color: Colors.amber, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMaxLevel ? Colors.amber.withOpacity(0.2) : Colors.cyanAccent,
                    foregroundColor: isMaxLevel ? Colors.amber : Colors.black,
                    disabledBackgroundColor: Colors.black38,
                    disabledForegroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: isMaxLevel || !canAfford ? 0 : 4,
                  ),
                  onPressed: (isMaxLevel || !canAfford || _isUpgrading) ? null : () => _showUpgradeDialog(user, skillDoc),
                  child: Text(isMaxLevel ? "Mastered" : "Upgrade", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyHeader(User user) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xFF16213E).withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 10, spreadRadius: 1),
          ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _currencyChip(
            icon: Icons.monetization_on,
            label: user.gold.toString(),
            color: Colors.amber,
          ),
          Container(width: 1, height: 24, color: Colors.white24),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}