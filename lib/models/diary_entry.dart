import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryEntry {
  final String id;
  final String content;
  final Timestamp timestamp;
  // final String? mood; // Optional: Add later if needed

  DiaryEntry({
    required this.id,
    required this.content,
    required this.timestamp,
    // this.mood,
  });

  factory DiaryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DiaryEntry(
      id: doc.id,
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      // mood: data['mood'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'timestamp': timestamp,
      // if (mood != null) 'mood': mood,
    };
  }
}
