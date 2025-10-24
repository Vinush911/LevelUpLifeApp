import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/epic_quest_model.dart';
import '../models/user.dart';

// Helper class for the Epic Quest dialog state
class _ChapterData {
  String? id;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController expController = TextEditingController();
  final TextEditingController goldController = TextEditingController();
  final TextEditingController statValueController = TextEditingController();
  String selectedStat = 'STR';

  _ChapterData({this.id, String title = '', String exp = '', String gold = '', String statValue = '', String stat = 'STR'}) {
    titleController.text = title;
    expController.text = exp;
    goldController.text = gold;
    statValueController.text = statValue;
    selectedStat = stat;
  }

  void dispose() {
    titleController.dispose();
    expController.dispose();
    goldController.dispose();
    statValueController.dispose();
  }
}


class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text("Admin Panel"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Daily Quests"),
            Tab(text: "Epic Quests"),
            Tab(text: "Main Quests"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DailyQuestsAdminView(),
          _EpicQuestsAdminView(),
          _MainQuestsAdminView(),
        ],
      ),
    );
  }
}

// --- Daily Quests Management ---
class _DailyQuestsAdminView extends StatefulWidget {
  @override
  __DailyQuestsAdminViewState createState() => __DailyQuestsAdminViewState();
}

class __DailyQuestsAdminViewState extends State<_DailyQuestsAdminView> {
  final _firestore = FirebaseFirestore.instance;

  void _showQuestDialog({DocumentSnapshot? quest}) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: quest?['title']);
    final expController = TextEditingController(text: quest?['totalExpReward']?.toString());
    final goldController = TextEditingController(text: quest?['goldReward']?.toString());
    final statValueController = TextEditingController();

    String selectedStat = 'STR';
    final stats = ['STR', 'END', 'DEX', 'INT', 'WIS', 'CHA'];

    if (quest != null && quest['statReward'] != null) {
      final statReward = quest['statReward'] as Map<String, dynamic>;
      if (statReward.isNotEmpty) {
        selectedStat = statReward.keys.first;
        statValueController.text = statReward.values.first.toString();
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(quest == null ? "Add Daily Quest" : "Edit Daily Quest"),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: titleController, decoration: const InputDecoration(labelText: "Title"), validator: (v) => v!.isEmpty ? "Required" : null),
                TextFormField(controller: expController, decoration: const InputDecoration(labelText: "EXP Reward"), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                TextFormField(controller: goldController, decoration: const InputDecoration(labelText: "Gold Reward"), keyboardType: TextInputType.number),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedStat,
                        items: stats.map((stat) => DropdownMenuItem(value: stat, child: Text(stat))).toList(),
                        onChanged: (value) => selectedStat = value!,
                        decoration: const InputDecoration(labelText: "Stat"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: statValueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Stat Points"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final statPoints = int.tryParse(statValueController.text) ?? 0;
                final data = {
                  'title': titleController.text,
                  'totalExpReward': double.tryParse(expController.text) ?? 0.0,
                  'goldReward': int.tryParse(goldController.text) ?? 0,
                  'statReward': statPoints > 0 ? { selectedStat: statPoints } : {},
                };
                if (quest == null) {
                  await _firestore.collection('daily_quests').add(data);
                } else {
                  await _firestore.collection('daily_quests').doc(quest.id).update(data);
                }
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('daily_quests').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final quest = doc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(quest['title'] ?? 'No Title'),
                subtitle: Text("EXP: ${quest['totalExpReward']}, Gold: ${quest['goldReward']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showQuestDialog(quest: doc)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => doc.reference.delete()),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuestDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}


// --- Epic Quests Management ---
class _EpicQuestsAdminView extends StatefulWidget {
  @override
  _EpicQuestsAdminViewState createState() => _EpicQuestsAdminViewState();
}

class _EpicQuestsAdminViewState extends State<_EpicQuestsAdminView> {

  Future<void> _deleteEpicQuest(BuildContext context, EpicQuest quest) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Text('This will permanently delete the Epic Quest "${quest.title}" and all its chapters. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      final firestore = FirebaseFirestore.instance;
      final questRef = firestore.collection('epic_quests').doc(quest.id);

      final chapters = await questRef.collection('chapters').get();
      final batch = firestore.batch();
      for (final doc in chapters.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(questRef);
      await batch.commit();
    }
  }

  void _showEditEpicQuestDialog(EpicQuest quest) async {
    final chaptersSnapshot = await FirebaseFirestore.instance.collection('epic_quests').doc(quest.id).collection('chapters').orderBy('order').get();

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: quest.title);
    final descriptionController = TextEditingController(text: quest.description);
    final finalGoldController = TextEditingController(text: quest.finalRewardGold.toString());
    final finalShardsController = TextEditingController(text: quest.finalRewardShards.toString());
    final finalStatValueController = TextEditingController();
    String selectedFinalStat = 'STR';
    final stats = ['STR', 'END', 'DEX', 'INT', 'WIS', 'CHA'];

    if (quest.finalStatReward != null && quest.finalStatReward!.isNotEmpty) {
      selectedFinalStat = quest.finalStatReward!.keys.first;
      finalStatValueController.text = quest.finalStatReward!.values.first.toString();
    }

    final List<_ChapterData> chaptersData = chaptersSnapshot.docs.map((doc) {
      final data = doc.data();
      final statReward = data['statReward'] as Map<String, dynamic>? ?? {};
      return _ChapterData(
        id: doc.id,
        title: data['title'] ?? '',
        exp: (data['rewardExp'] ?? 0).toString(),
        gold: (data['rewardGold'] ?? 0).toString(),
        stat: statReward.isNotEmpty ? statReward.keys.first : 'STR',
        statValue: statReward.isNotEmpty ? statReward.values.first.toString() : '',
      );
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Dialog content remains largely the same as creation, but for editing
            return AlertDialog(
              title: const Text("Edit Epic Quest"),
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
                                if (value != null) setDialogState(() => selectedFinalStat = value);
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
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setDialogState(() => chaptersData.removeAt(idx))),
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
                                          if (value != null) setDialogState(() => data.selectedStat = value);
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
                  onPressed: () => _updateEpicQuest(
                    formKey,
                    quest,
                    titleController,
                    descriptionController,
                    finalGoldController,
                    finalShardsController,
                    chaptersData,
                    selectedFinalStat,
                    finalStatValueController,
                  ),
                  child: const Text("Update Quest"),
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

  Future<void> _updateEpicQuest(
      GlobalKey<FormState> formKey,
      EpicQuest originalQuest,
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
    final epicQuestRef = firestore.collection('epic_quests').doc(originalQuest.id);

    Map<String, dynamic> finalStatReward = {};
    final statPoints = int.tryParse(finalStatValue.text);
    if (statPoints != null && statPoints > 0) {
      finalStatReward = {selectedStat: statPoints};
    }

    batch.update(epicQuestRef, {
      'title': title.text,
      'description': description.text,
      'finalRewardGold': int.parse(finalGold.text),
      'finalRewardShards': int.parse(finalShards.text),
      'finalStatReward': finalStatReward,
    });

    // Simple approach: delete all old chapters and add the new ones
    final oldChapters = await epicQuestRef.collection('chapters').get();
    for (final doc in oldChapters.docs) {
      batch.delete(doc.reference);
    }

    for (int i = 0; i < chaptersData.length; i++) {
      final chapter = chaptersData[i];
      final chapterRef = epicQuestRef.collection('chapters').doc(); // new ID for each

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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Epic Quest updated successfully!"), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('epic_quests').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final quests = snapshot.data!.docs.map((doc) => EpicQuest.fromFirestore(doc)).toList();

        return ListView.builder(
          itemCount: quests.length,
          itemBuilder: (context, index) {
            final quest = quests[index];
            return ListTile(
              title: Text(quest.title),
              subtitle: Text(quest.description),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditEpicQuestDialog(quest),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteEpicQuest(context, quest),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// --- Main Quests Management (Admin) ---
class _MainQuestsAdminView extends StatefulWidget {
  @override
  __MainQuestsAdminViewState createState() => __MainQuestsAdminViewState();
}

class __MainQuestsAdminViewState extends State<_MainQuestsAdminView> {
  User? _selectedUser;

  Future<void> _deleteMainQuest(String questId) async {
    if (_selectedUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quest?'),
        content: const Text('Are you sure you want to permanently delete this main quest?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_selectedUser!.uid)
          .collection('quests')
          .doc(questId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedUser == null) {
      // Show user list
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final users = snapshot.data!.docs.map((doc) => User.fromFirestore(doc)).toList();
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.name),
                subtitle: Text("Level ${user.level}"),
                onTap: () => setState(() => _selectedUser = user),
              );
            },
          );
        },
      );
    } else {
      // Show quest list for selected user
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedUser = null)),
                Text("Quests for ${_selectedUser!.name}", style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_selectedUser!.uid)
                  .collection('quests')
                  .where('completed', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    final quest = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(quest['title'] ?? 'No Title'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteMainQuest(doc.id),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      );
    }
  }
}

