import 'package:cloud_firestore/cloud_firestore.dart';

class Guild {
  final String id;
  final String name;
  final String tag;
  final String description;
  final String leaderId;
  final List<String> members;
  final Timestamp createdAt;
  // --- NEW FIELD ---
  final String? emblemUrl;

  Guild({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
    required this.leaderId,
    required this.members,
    required this.createdAt,
    // --- NEW FIELD ---
    this.emblemUrl,
  });

  factory Guild.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Guild(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Guild',
      tag: data['tag'] ?? 'NULL',
      description: data['description'] ?? '',
      leaderId: data['leaderId'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      // --- NEW FIELD ---
      emblemUrl: data['emblemUrl'] as String?,
    );
  }
}

