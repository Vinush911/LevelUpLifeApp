import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/epic_quest_model.dart';
import '../models/chapter_model.dart';

class _ChapterData {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController expController = TextEditingController();
  final TextEditingController goldController = TextEditingController();
  final TextEditingController statValueController = TextEditingController();
  String selectedStat = 'STR';

  void dispose() {
    titleController.dispose();
    expController.dispose();
    goldController.dispose();
    statValueController.dispose();
  }
}

class EpicQuestsScreen extends StatefulWidget {
  final String uid;
  const EpicQuestsScreen({super.key, required this.uid});

  @override
  State<EpicQuestsScreen> createState() => _EpicQuestsScreenState();
}

class _EpicQuestsScreenState extends State<EpicQuestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _completeChapter(EpicQuest quest, Chapter chapter) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.uid);
    final questProgressRef = userRef.collection('epic_quests').doc(quest.id);
    final chapterProgressRef = questProgressRef.collection('chapters').doc(chapter.id);

    try {
      // --- REFACTOR: Switched to Batched Writes for Offline Support ---
      final userDoc = await userRef.get();
      if (!userDoc.exists) throw Exception("User not found");

      final user = User.fromFirestore(userDoc);

      user.gold += chapter.rewardGold;
      user.exp += chapter.rewardExp;

      if (chapter.statReward != null && chapter.statReward!.isNotEmpty) {
        final statName = chapter.statReward!.keys.first;
        final pointsToAdd = (chapter.statReward!.values.first as num).toInt();
        user.stats[statName] = (user.stats[statName] ?? 0) + pointsToAdd;
      }

      final batch = firestore.batch();
      batch.update(userRef, {
        'gold': user.gold,
        'exp': user.exp,
        'stats': user.stats
      });
      batch.set(chapterProgressRef, {'isCompleted': true}, SetOptions(merge: true));
      batch.set(questProgressRef, {'id': quest.id}, SetOptions(merge: true));
      await batch.commit();
      // --- END REFACTOR ---

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Chapter '${chapter.title}' completed!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error completing chapter: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("An error occurred: $e")));
      }
    }
  }

  Future<void> _claimFinalReward(User user, EpicQuest quest) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(widget.uid);
    final questProgressRef = userRef.collection('epic_quests').doc(quest.id);

    try {
      // --- REFACTOR: Switched to Batched Writes for Offline Support ---
      final freshUserDoc = await userRef.get();
      if (!freshUserDoc.exists) throw Exception("User not found");
      final freshUser = User.fromFirestore(freshUserDoc);

      freshUser.gold += quest.finalRewardGold;
      freshUser.gachaShards += quest.finalRewardShards;

      if (quest.finalStatReward != null && quest.finalStatReward!.isNotEmpty) {
        final statName = quest.finalStatReward!.keys.first;
        final pointsToAdd = (quest.finalStatReward!.values.first as num).toInt();
        freshUser.stats[statName] = (freshUser.stats[statName] ?? 0) + pointsToAdd;
      }

      final batch = firestore.batch();
      batch.update(userRef, {
        'gold': freshUser.gold,
        'gachaShards': freshUser.gachaShards,
        'stats': freshUser.stats,
      });
      batch.update(questProgressRef, {'isCompleted': true});
      await batch.commit();
      // --- END REFACTOR ---

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Epic Quest '${quest.title}' completed! Final reward claimed!"), backgroundColor: Colors.amber),
        );
      }
    } catch (e) {
      debugPrint("Error claiming final reward: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("An error occurred: $e")));
      }
    }
  }

  void _showAddEpicQuestDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final finalGoldController = TextEditingController();
    final finalShardsController = TextEditingController();
    final finalStatValueController = TextEditingController();
    String selectedFinalStat = 'STR';
    final stats = ['STR', 'END', 'DEX', 'INT', 'WIS', 'CHA'];
    final List<_ChapterData> chaptersData = [_ChapterData()];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Create New Epic Quest"),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(controller: titleController, decoration: const InputDecoration(labelText: "Quest Title"), validator: (v) => v!.isEmpty ? "Required" : null),
                      TextFormField(controller: descriptionController, decoration: const InputDecoration(labelText: "Description"), validator: (v) => v!.isEmpty ? "Required" : null),
                      TextFormField(controller: finalGoldController, decoration: const InputDecoration(labelText: "Final Gold Reward"), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? "Required" : null),
                      TextFormField(controller: finalShardsController, decoration: const InputDecoration(labelText: "Final Shard Reward"), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? "Required" : null),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedFinalStat,
                              items: stats.map((stat) => DropdownMenuItem(value: stat, child: Text(stat))).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => selectedFinalStat = value);
                                }
                              },
                              decoration: const InputDecoration(labelText: "Final Stat Reward"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: finalStatValueController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: "Stat Points"),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 30),
                      const Text("Chapters", style: TextStyle(fontWeight: FontWeight.bold)),
                      ...chaptersData.asMap().entries.map((entry) {
                        int idx = entry.key;
                        _ChapterData data = entry.value;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text("Chapter ${idx + 1}", style: const TextStyle(fontWeight: FontWeight.bold))),
                                    if (chaptersData.length > 1) IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setDialogState(() => chaptersData.removeAt(idx))),
                                  ],
                                ),
                                TextFormField(controller: data.titleController, decoration: const InputDecoration(labelText: "Title"), validator: (v) => v!.isEmpty ? "Required" : null),
                                TextFormField(controller: data.expController, decoration: const InputDecoration(labelText: "EXP Reward"), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? "Required" : null),
                                TextFormField(controller: data.goldController, decoration: const InputDecoration(labelText: "Gold Reward"), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? "Required" : null),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: data.selectedStat,
                                        items: stats.map((stat) => DropdownMenuItem(value: stat, child: Text(stat))).toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setDialogState(() => data.selectedStat = value);
                                          }
                                        },
                                        decoration: const InputDecoration(labelText: "Stat Reward"),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: data.statValueController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(labelText: "Points"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      TextButton.icon(icon: const Icon(Icons.add), label: const Text("Add Chapter"), onPressed: () => setDialogState(() => chaptersData.add(_ChapterData()))),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () => _saveEpicQuest(
                    formKey,
                    titleController,
                    descriptionController,
                    finalGoldController,
                    finalShardsController,
                    chaptersData,
                    selectedFinalStat,
                    finalStatValueController,
                  ),
                  child: const Text("Save Quest"),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      for (var chapter in chaptersData) {
        chapter.dispose();
      }
    });
  }

  Future<void> _saveEpicQuest(
      GlobalKey<FormState> formKey,
      TextEditingController title,
      TextEditingController description,
      TextEditingController finalGold,
      TextEditingController finalShards,
      List<_ChapterData> chaptersData,
      String selectedStat,
      TextEditingController finalStatValue,
      ) async {
    if (!formKey.currentState!.validate()) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final epicQuestRef = firestore.collection('epic_quests').doc();

    Map<String, dynamic> finalStatReward = {};
    final statPoints = int.tryParse(finalStatValue.text);
    if (statPoints != null && statPoints > 0) {
      finalStatReward = {selectedStat: statPoints};
    }

    batch.set(epicQuestRef, {
      'title': title.text,
      'description': description.text,
      'finalRewardGold': int.parse(finalGold.text),
      'finalRewardShards': int.parse(finalShards.text),
      'finalStatReward': finalStatReward,
      'isCompleted': false,
      'createdAt': Timestamp.now(),
    });

    for (int i = 0; i < chaptersData.length; i++) {
      final chapter = chaptersData[i];
      final chapterRef = epicQuestRef.collection('chapters').doc();

      Map<String, dynamic> chapterStatReward = {};
      final chapterStatPoints = int.tryParse(chapter.statValueController.text);
      if (chapterStatPoints != null && chapterStatPoints > 0) {
        chapterStatReward = {chapter.selectedStat: chapterStatPoints};
      }

      batch.set(chapterRef, {
        'title': chapter.titleController.text,
        'rewardExp': int.parse(chapter.expController.text),
        'rewardGold': int.parse(chapter.goldController.text),
        'statReward': chapterStatReward,
        'isCompleted': false,
        'order': i,
      });
    }

    await batch.commit();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Epic Quest created successfully!"), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
        builder: (context, userSnapshot) {
          final bool isAdmin = userSnapshot.hasData ? User.fromFirestore(userSnapshot.data).isAdmin == true : false;

          return Scaffold(
            appBar: AppBar(
              title: const Text("Epic Quests"),
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: "Active"),
                  Tab(text: "Completed"),
                ],
              ),
            ),
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('epic_quests').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, questSnapshot) {
                if (!questSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                final allEpicQuests = questSnapshot.data!.docs.map((doc) => EpicQuest.fromFirestore(doc)).toList();

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('epic_quests').where('isCompleted', isEqualTo: true).snapshots(),
                  builder: (context, userProgressSnapshot) {
                    final completedQuestIds = userProgressSnapshot.hasData ? userProgressSnapshot.data!.docs.map((doc) => doc.id).toSet() : <String>{};

                    final activeQuests = allEpicQuests.where((q) => !completedQuestIds.contains(q.id)).toList();
                    final completedQuests = allEpicQuests.where((q) => completedQuestIds.contains(q.id)).toList();

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildQuestListView(activeQuests, "No active Epic Quests."),
                        _buildQuestListView(completedQuests, "You have not completed any Epic Quests."),
                      ],
                    );
                  },
                );
              },
            ),
            floatingActionButton: isAdmin
                ? FloatingActionButton(
              onPressed: _showAddEpicQuestDialog,
              tooltip: "Create Epic Quest",
              child: const Icon(Icons.add),
            )
                : null,
          );
        }
    );
  }

  Widget _buildQuestListView(List<EpicQuest> quests, String emptyMessage) {
    if (quests.isEmpty) {
      return Center(child: Text(emptyMessage));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: quests.length,
      itemBuilder: (context, index) {
        final quest = quests[index];
        return _buildEpicQuestCard(context, quest);
      },
    );
  }

  String _getFinalRewardString(EpicQuest quest) {
    List<String> rewards = [];
    if (quest.finalRewardGold > 0) rewards.add("${quest.finalRewardGold} Gold");
    if (quest.finalRewardShards > 0) rewards.add("${quest.finalRewardShards} Shards");
    if (quest.finalStatReward != null && quest.finalStatReward!.isNotEmpty) {
      rewards.add("+${quest.finalStatReward!.values.first} ${quest.finalStatReward!.keys.first}");
    }
    return rewards.join(', ');
  }

  Widget _buildEpicQuestCard(BuildContext context, EpicQuest quest) {
    final finalRewardString = _getFinalRewardString(quest);

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quest.title, style: Theme.of(context).textTheme.headlineSmall),
            Text(quest.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade400)),
            const SizedBox(height: 16),
            if (finalRewardString.isNotEmpty) ...[
              Text("Final Rewards", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(finalRewardString, style: TextStyle(color: Colors.amber.shade200)),
            ],
            const Divider(height: 24),
            Text("Chapters", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('epic_quests')
                  .doc(quest.id)
                  .collection('chapters')
                  .orderBy('order')
                  .snapshots(),
              builder: (context, chapterSnapshot) {
                if (!chapterSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                final chapters = chapterSnapshot.data!.docs.map((doc) => Chapter.fromFirestore(doc)).toList();

                return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('epic_quests').doc(quest.id).snapshots(),
                    builder: (context, userQuestProgressSnapshot) {
                      final isQuestCompletedByUser = userQuestProgressSnapshot.hasData && (userQuestProgressSnapshot.data!.data() as Map<String, dynamic>?)?['isCompleted'] == true;

                      return Column(
                        children: [
                          ...chapters.map((chapter) {
                            return StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(widget.uid)
                                    .collection('epic_quests')
                                    .doc(quest.id)
                                    .collection('chapters')
                                    .doc(chapter.id)
                                    .snapshots(),
                                builder: (context, userChapterProgressSnapshot) {
                                  final isChapterCompletedByUser = userChapterProgressSnapshot.hasData && (userChapterProgressSnapshot.data!.data() as Map<String, dynamic>?)?['isCompleted'] == true;
                                  return _buildChapterTile(chapter, quest, isChapterCompletedByUser);
                                }
                            );
                          }),
                          const SizedBox(height: 16),
                          _buildFinalRewardButton(quest, chapters, isQuestCompletedByUser),
                        ],
                      );
                    }
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalRewardButton(EpicQuest quest, List<Chapter> chapters, bool isQuestCompletedByUser) {
    if (isQuestCompletedByUser) {
      return const Chip(label: Text("Quest Complete!"), backgroundColor: Colors.green);
    }

    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('epic_quests').doc(quest.id).collection('chapters').where('isCompleted', isEqualTo: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();

          final completedChaptersCount = snapshot.data!.docs.length;
          final allChaptersComplete = completedChaptersCount >= chapters.length && chapters.isNotEmpty;

          if (allChaptersComplete) {
            return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return const SizedBox.shrink();
                  final user = User.fromFirestore(userSnapshot.data);
                  return ElevatedButton.icon(
                    onPressed: () => _claimFinalReward(user, quest),
                    icon: const Icon(Icons.celebration),
                    label: const Text("Claim Final Reward!"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  );
                }
            );
          }
          return const SizedBox.shrink();
        }
    );
  }

  String _getChapterRewardString(Chapter chapter) {
    List<String> rewards = [];
    if (chapter.rewardExp > 0) rewards.add("${chapter.rewardExp} EXP");
    if (chapter.rewardGold > 0) rewards.add("${chapter.rewardGold} Gold");
    if (chapter.statReward != null && chapter.statReward!.isNotEmpty) {
      rewards.add("+${chapter.statReward!.values.first} ${chapter.statReward!.keys.first}");
    }
    return "Reward: ${rewards.join(', ')}";
  }

  Widget _buildChapterTile(Chapter chapter, EpicQuest quest, bool isCompleted) {
    return ListTile(
      leading: Icon(isCompleted ? Icons.check_circle : Icons.circle_outlined, color: isCompleted ? Colors.green : Colors.grey),
      title: Text(chapter.title, style: TextStyle(decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none)),
      subtitle: Text(_getChapterRewardString(chapter)),
      trailing: isCompleted
          ? null
          : ElevatedButton(
        onPressed: () => _completeChapter(quest, chapter),
        child: const Text("Complete"),
      ),
    );
  }
}
