import 'package:cloud_firestore/cloud_firestore.dart';

class Chapter {
  final String id;
  final String title;
  final bool isCompleted;
  final int rewardGold;
  final int rewardExp;
  final int order;
  // --- FIX: Added the missing statReward field ---
  final Map<String, dynamic>? statReward;

  Chapter({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.rewardGold,
    required this.rewardExp,
    required this.order,
    // --- FIX: Added to constructor ---
    this.statReward,
  });

  factory Chapter.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chapter(
      id: doc.id,
      title: data['title'] ?? 'Untitled Chapter',
      isCompleted: data['isCompleted'] ?? false,
      rewardGold: (data['rewardGold'] as num? ?? 0).toInt(),
      rewardExp: (data['rewardExp'] as num? ?? 0).toInt(),
      order: (data['order'] as num? ?? 0).toInt(),
      // --- FIX: Added logic to read from Firestore ---
      statReward: data['statReward'] != null ? Map<String, dynamic>.from(data['statReward']) : null,
    );
  }
}

