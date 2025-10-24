import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/user.dart';
import '../widgets/level_up_overlay.dart';
import '../widgets/unlock_overlay.dart';
import 'dart:async';

// Helper function to log user activity
Future<void> _logActivity(String uid) async {
  final firestore = FirebaseFirestore.instance;
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final activityRef = firestore.collection('users').doc(uid).collection('activity_log').doc(today);

  // This operation will also work offline and sync later.
  await activityRef.set({
    'questsCompleted': FieldValue.increment(1),
    'timestamp': Timestamp.now(),
  }, SetOptions(merge: true));
}

class QuestScreen extends StatelessWidget {
  final String uid;
  const QuestScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = User.fromFirestore(snapshot.data);
        // Regenerate energy on build to update the initial check for the FAB
        user.regenerateEnergy();

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text("Quest Log"),
              bottom: const TabBar(
                tabs: [
                  Tab(text: "Main"),
                  Tab(text: "Daily"),
                  Tab(text: "Completed"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _MainQuestsView(uid: uid),
                _DailyQuestsView(uid: uid),
                _CompletedQuestsView(uid: uid),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              tooltip: "Add Main Quest",
              child: const Icon(Icons.add),
              onPressed: () {
                const int creationCost = 5;
                if (user.currentEnergy < creationCost) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Not enough energy to create a quest."),
                      backgroundColor: Colors.orange,
                    ),
                  );
                } else {
                  _showAddMainQuestDialog(context, uid);
                }
              },
            ),
          ),
        );
      },
    );
  }
}


// --- Main Quest Card Widget ---
class _MainQuestCard extends StatefulWidget {
  final String questId;
  final String uid;
  final Map<String, dynamic> quest;
  final VoidCallback onComplete;

  const _MainQuestCard({
    super.key,
    required this.questId,
    required this.uid,
    required this.quest,
    required this.onComplete,
  });

  @override
  State<_MainQuestCard> createState() => _MainQuestCardState();
}

class _MainQuestCardState extends State<_MainQuestCard> {
  bool _isProcessing = false;

  void _handlePress() {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    widget.onComplete();
    // Re-enable button after a delay to prevent spam and show feedback
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  Future<void> _deleteQuest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quest?'),
        content: Text('Are you sure you want to delete "${widget.quest['title']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && mounted) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('quests')
          .doc(widget.questId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.quest['title'] ?? 'Unnamed Quest';
    final rewards = _getRewardString(widget.quest);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.star, color: Colors.yellowAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (rewards.isNotEmpty) const SizedBox(height: 4),
                  if (rewards.isNotEmpty) Text(rewards, style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                ],
              ),
            ),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
              )
            else
              ElevatedButton(
                onPressed: _handlePress,
                child: const Icon(Icons.check),
              ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.grey.shade600),
              onPressed: _deleteQuest,
              tooltip: "Delete Quest",
            ),
          ],
        ),
      ),
    );
  }
}


// --- Daily Quest Card UI Widget ---
class _DailyQuestCard extends StatelessWidget {
  final Map<String, dynamic> questData;
  final bool isCompleted;
  final int streak;
  final VoidCallback onComplete;

  const _DailyQuestCard({
    required this.questData,
    required this.isCompleted,
    required this.streak,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final title = questData['title'] ?? 'Unnamed Quest';
    final rewards = _getRewardString(questData);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: isCompleted ? Colors.grey.shade800.withOpacity(0.5) : null,
      child: ListTile(
        leading: Icon(Icons.repeat, color: isCompleted ? Colors.grey : Colors.tealAccent),
        title: Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: isCompleted ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
                  decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (streak > 0) ...[
              const SizedBox(width: 8),
              const Icon(Icons.whatshot, color: Colors.orange, size: 16),
              const SizedBox(width: 4),
              Text(streak.toString(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
        subtitle: Text(
          rewards,
          style: TextStyle(color: isCompleted ? Colors.grey.shade600 : Colors.tealAccent.shade200),
        ),
        trailing: isCompleted
            ? const Icon(Icons.check_circle, color: Colors.greenAccent)
            : ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
          onPressed: onComplete,
          child: const Text("Claim"),
        ),
      ),
    );
  }
}

// --- Stateful Wrapper for Daily Quests ---
class _DailyQuestStateWrapper extends StatelessWidget {
  final DocumentSnapshot questDoc;
  final String uid;

  const _DailyQuestStateWrapper({
    super.key,
    required this.questDoc,
    required this.uid,
  });

  Future<void> _completeDailyQuest(BuildContext context) async {
    final questId = questDoc.id;
    final questData = questDoc.data() as Map<String, dynamic>;
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);
    final dailyStatusRef = userRef.collection('daily_quest_status').doc(questId);

    try {
      final userDoc = await userRef.get();
      if (!userDoc.exists) throw Exception("User not found");
      final dailyStatusDoc = await dailyStatusRef.get();

      final user = User.fromFirestore(userDoc);
      final initialLevel = user.level;
      bool bonusAwarded = false;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
      int currentStreak = 0;

      if (dailyStatusDoc.exists) {
        final statusData = dailyStatusDoc.data() as Map<String, dynamic>;
        final lastCompleted = statusData['lastCompleted'] as String?;
        if (lastCompleted == yesterday) {
          currentStreak = (statusData['streak'] ?? 0) as int;
        }
      }
      int newStreak = currentStreak + 1;

      double expToAdd = (questData['totalExpReward'] ?? 0).toDouble();
      int goldToAdd = ((questData['goldReward'] ?? 0) as num).toInt();

      final statReward = questData['statReward'] as Map<String, dynamic>? ?? {};
      if (statReward.isNotEmpty) {
        final statName = statReward.keys.first;
        int pointsToAdd = ((statReward.values.first ?? 0) as num).toInt();
        user.stats[statName] = (user.stats[statName] ?? 0) + pointsToAdd;
      }

      if (newStreak % 7 == 0 && newStreak > 0) {
        goldToAdd += 100;
        bonusAwarded = true;
      }

      user.exp += expToAdd;
      user.gold += goldToAdd;

      // --- MODIFIED: Grant unassigned stat points on level up ---
      while (user.exp >= user.nextLevelExp()) {
        user.exp -= user.nextLevelExp();
        user.level += 1;
        user.unassignedStatPoints += 3; // Grant 3 points per level
        user.updateTitle();
      }

      final batch = firestore.batch();
      batch.set(userRef, user.toMap());
      batch.set(dailyStatusRef, {'lastCompleted': today, 'streak': newStreak});
      await batch.commit();

      await _logActivity(uid);

      if (context.mounted) {
        List<Function> animationPipeline = [
              () => showUnlockOverlay(context, unlockTitle: "DAILY COMPLETE", itemName: questData['title'] ?? 'Quest', iconData: Icons.check_circle, color: Colors.tealAccent)
        ];

        if (bonusAwarded) {
          animationPipeline.add(() => showUnlockOverlay(context, unlockTitle: "STREAK BONUS!", itemName: "+100 Gold", iconData: Icons.whatshot, color: Colors.orangeAccent));
        }

        if (user.level > initialLevel) {
          animationPipeline.add(() => showLevelUpOverlay(context, user.level));
        }

        final unlocks = await _getPostQuestUnlocks(uid, user);
        for (final item in unlocks) {
          animationPipeline.add(() => showUnlockOverlay(context, unlockTitle: item['unlockTitle'], itemName: item['itemName'], iconData: item['iconData'], color: item['color']));
        }

        for (final animationFunction in animationPipeline) {
          await animationFunction();
        }
      }

    } catch (e) {
      debugPrint("Error completing daily quest: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('daily_quest_status').doc(questDoc.id).snapshots(),
      builder: (context, statusSnapshot) {
        bool isCompletedToday = false;
        int currentStreak = 0;
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));

        if (statusSnapshot.hasData && statusSnapshot.data!.exists) {
          final statusData = statusSnapshot.data!.data() as Map<String, dynamic>;
          final lastCompleted = statusData['lastCompleted'] as String?;

          if (lastCompleted == today) {
            isCompletedToday = true;
            currentStreak = (statusData['streak'] ?? 0) as int;
          } else if (lastCompleted == yesterday) {
            currentStreak = (statusData['streak'] ?? 0) as int;
          }
        }

        return _DailyQuestCard(
          questData: questDoc.data() as Map<String, dynamic>,
          isCompleted: isCompletedToday,
          streak: currentStreak,
          onComplete: () => _completeDailyQuest(context),
        );
      },
    );
  }
}

// --- Main Quests View (Handles completion logic) ---
class _MainQuestsView extends StatelessWidget {
  final String uid;
  const _MainQuestsView({required this.uid});

  Future<void> _trimCompletedQuests(FirebaseFirestore firestore, DocumentReference userRef) async {
    const int questsToKeep = 20;

    final completedQuestsQuery = userRef
        .collection('quests')
        .where('completed', isEqualTo: true)
        .orderBy('completedAt', descending: false);

    final completedQuestsSnapshot = await completedQuestsQuery.get();

    if (completedQuestsSnapshot.docs.length > questsToKeep) {
      final batch = firestore.batch();
      final questsToDelete = completedQuestsSnapshot.docs.length - questsToKeep;

      for (int i = 0; i < questsToDelete; i++) {
        batch.delete(completedQuestsSnapshot.docs[i].reference);
      }

      await batch.commit();
    }
  }

  Future<void> _completeQuest(BuildContext context, Map<String, dynamic> quest, String questId) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);

    try {
      final userDoc = await userRef.get();
      if (!userDoc.exists) throw Exception("User not found");

      final user = User.fromFirestore(userDoc);
      final initialLevel = user.level;

      user.regenerateEnergy();

      const int completionCost = 10;
      if (user.currentEnergy < completionCost) {
        throw Exception("You are too tired to complete this quest. Rest for a while.");
      }
      user.currentEnergy -= completionCost;

      user.exp += (quest['totalExpReward'] ?? 0).toDouble();
      user.gold += ((quest['goldReward'] ?? 0) as num).toInt();

      // --- MODIFIED: Grant unassigned stat points on level up ---
      while (user.exp >= user.nextLevelExp()) {
        user.exp -= user.nextLevelExp();
        user.level += 1;
        user.unassignedStatPoints += 3; // Grant 3 points per level
        user.updateTitle();
      }

      final batch = firestore.batch();
      batch.set(userRef, user.toMap());
      batch.update(userRef.collection('quests').doc(questId), {
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      await _trimCompletedQuests(firestore, userRef);

      await _logActivity(uid);

      if (context.mounted) {
        List<Function> animationPipeline = [
              () => showUnlockOverlay(context, unlockTitle: "QUEST COMPLETE", itemName: quest['title'] ?? 'Quest', iconData: Icons.check_circle, color: Colors.green)
        ];

        if (user.level > initialLevel) {
          animationPipeline.add(() => showLevelUpOverlay(context, user.level));
        }

        final unlocks = await _getPostQuestUnlocks(uid, user);
        for (final item in unlocks) {
          animationPipeline.add(() => showUnlockOverlay(context, unlockTitle: item['unlockTitle'], itemName: item['itemName'], iconData: item['iconData'], color: item['color']));
        }

        for (final animationFunction in animationPipeline) {
          await animationFunction();
        }
      }
    } catch (e) {
      debugPrint('Error completing quest: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('quests').where('completed', isEqualTo: false).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No active main quests."));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (listViewContext, index) {
              final questDoc = snapshot.data!.docs[index];
              final questData = questDoc.data() as Map<String, dynamic>;
              return _MainQuestCard(
                key: ValueKey(questDoc.id),
                questId: questDoc.id,
                uid: uid,
                quest: questData,
                onComplete: () => _completeQuest(context, questData, questDoc.id),
              );
            },
          );
        });
  }
}

// --- Daily Quests View ---
class _DailyQuestsView extends StatelessWidget {
  final String uid;
  const _DailyQuestsView({required this.uid});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('daily_quests').snapshots(),
      builder: (context, questSnapshot) {
        if (!questSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (questSnapshot.data!.docs.isEmpty) return const Center(child: Text("No daily quests available."));

        final dailyQuests = questSnapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: dailyQuests.length,
          itemBuilder: (context, index) {
            final quest = dailyQuests[index];
            return _DailyQuestStateWrapper(
              key: ValueKey(quest.id),
              questDoc: quest,
              uid: uid,
            );
          },
        );
      },
    );
  }
}

// --- Helper Functions and Other Widgets ---

String _getRewardString(Map<String, dynamic> questData) {
  List<String> rewards = [];
  final totalExp = (questData['totalExpReward'] ?? 0).toInt();
  final goldReward = (questData['goldReward'] ?? 0).toInt();

  // --- MODIFIED: Only show stat rewards if they exist (for daily quests) ---
  final statReward = questData['statReward'] as Map<String, dynamic>?;
  if (statReward != null && statReward.isNotEmpty) {
    final points = statReward.values.first;
    if (points > 0) rewards.add("+$points ${statReward.keys.first}");
  }

  if (totalExp > 0) rewards.add("+$totalExp EXP");
  if (goldReward > 0) rewards.add("+$goldReward Gold");

  return rewards.join(' • ');
}

class _CompletedQuestsView extends StatelessWidget {
  final String uid;
  const _CompletedQuestsView({required this.uid});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('quests')
            .where('completed', isEqualTo: true)
            .orderBy('completedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No completed quests yet."));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final quest = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String completedDate = '';
              if (quest.containsKey('completedAt') && quest['completedAt'] != null) {
                final timestamp = quest['completedAt'] as Timestamp;
                completedDate = DateFormat.yMMMd().format(timestamp.toDate());
              }

              return Card(
                color: Colors.black26,
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.greenAccent),
                  title: Text(quest['title'] ?? 'Quest', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                  subtitle: completedDate.isNotEmpty ? Text('Completed on $completedDate', style: TextStyle(color: Colors.grey.shade600)) : null,
                ),
              );
            },
          );
        });
  }
}

Future<List<Map<String, dynamic>>> _getPostQuestUnlocks(String uid, User user) async {
  final firestore = FirebaseFirestore.instance;
  final userRef = firestore.collection('users').doc(uid);
  final List<Map<String, dynamic>> newlyUnlockedItems = [];

  if (user.level >= 10 && user.userClass == null) {
    String highestStat = 'STR';
    int highestValue = 0;
    user.stats.forEach((key, value) {
      if (value > highestValue) {
        highestValue = value;
        highestStat = key;
      }
    });
    final classesQuery = await firestore.collection('classes').where('unlockStat', isEqualTo: highestStat).limit(1).get();
    if (classesQuery.docs.isNotEmpty) {
      final className = classesQuery.docs.first.data()['name'] as String;
      await userRef.update({'userClass': className});
      user.userClass = className;
      newlyUnlockedItems.add({'unlockTitle': "CLASS UNLOCKED", 'itemName': className, 'iconData': Icons.shield, 'color': Colors.cyan});
    }
  }

  final allAchievements = await firestore.collection('achievements').get();
  for (var doc in allAchievements.docs) {
    final achievementId = doc.id;
    final achievement = doc.data();
    if (!user.unlockedAchievements.containsKey(achievementId)) {
      bool shouldUnlock = false;
      final type = (achievement['type'] as String? ?? '').toUpperCase();
      final threshold = (achievement['threshold'] as num? ?? 0).toInt();
      if (type == 'LEVEL' && user.level >= threshold) shouldUnlock = true;
      if (type == 'STAT') {
        final stat = (achievement['stat'] as String? ?? '').toUpperCase();
        if (stat.isNotEmpty && user.stats.containsKey(stat) && user.stats[stat]! >= threshold) {
          shouldUnlock = true;
        }
      }
      if (shouldUnlock) {
        await userRef.update({'unlockedAchievements.$achievementId': Timestamp.now()});
        newlyUnlockedItems.add({'unlockTitle': "ACHIEVEMENT UNLOCKED", 'itemName': achievement['title'], 'iconData': Icons.emoji_events, 'color': Colors.amber});
      }
    }
  }
  return newlyUnlockedItems;
}

void _showAddMainQuestDialog(BuildContext context, String uid) {
  final titleController = TextEditingController();
  final random = Random();

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF16213E),
      title: const Text("Add a New Main Quest", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: "Quest Title", labelStyle: TextStyle(color: Colors.purple.shade200)),
            ),
            const SizedBox(height: 16),
            Text(
              "Rewards will be randomized upon creation.",
              style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(context)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
          child: const Text("Add Quest"),
          onPressed: () async {
            final title = titleController.text.trim();
            if (title.isNotEmpty) {
              final firestore = FirebaseFirestore.instance;
              final userRef = firestore.collection('users').doc(uid);
              const int creationCost = 10;

              try {
                final userDoc = await userRef.get();
                if (!userDoc.exists) throw Exception("User not found");

                final user = User.fromFirestore(userDoc);
                user.regenerateEnergy();

                if (user.currentEnergy < creationCost) {
                  throw Exception("Not enough energy to create a quest.");
                }

                user.currentEnergy -= creationCost;

                final totalExp = 50 + random.nextInt(151);
                final goldReward = 10 + random.nextInt(91);

                final newQuestRef = userRef.collection('quests').doc();

                final batch = firestore.batch();
                // --- MODIFIED: No longer adding statReward to new main quests ---
                batch.set(newQuestRef, {
                  'title': title,
                  'completed': false,
                  'totalExpReward': totalExp,
                  'goldReward': goldReward,
                });
                batch.update(userRef, user.toMap());
                await batch.commit();

                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll("Exception: ", "")),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
        ),
      ],
    ),
  );
}

