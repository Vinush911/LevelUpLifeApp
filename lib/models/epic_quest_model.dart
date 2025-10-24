import 'package:cloud_firestore/cloud_firestore.dart';

class EpicQuest {
  final String id;
  final String title;
  final String description;
  final int finalRewardGold;
  final int finalRewardShards;
  final bool isCompleted;
  final Timestamp createdAt;
  // --- NEW FIELD ---
  final Map<String, dynamic>? finalStatReward;


  EpicQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.finalRewardGold,
    required this.finalRewardShards,
    required this.isCompleted,
    required this.createdAt,
    // --- NEW FIELD ---
    this.finalStatReward,
  });

  factory EpicQuest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EpicQuest(
      id: doc.id,
      title: data['title'] ?? 'Untitled Quest',
      description: data['description'] ?? '',
      finalRewardGold: (data['finalRewardGold'] as num? ?? 0).toInt(),
      finalRewardShards: (data['finalRewardShards'] as num? ?? 0).toInt(),
      isCompleted: data['isCompleted'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      // --- NEW FIELD ---
      finalStatReward: data['finalStatReward'] != null ? Map<String, dynamic>.from(data['finalStatReward']) : null,
    );
  }
}
