import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String title;
  final String content; // Now holds JSON Delta
  final String plainTextPreview; // Holds plain text for grid cards
  final Timestamp createdAt;
  final Timestamp lastModified;
  final bool isPinned;
  final int colorHex;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.plainTextPreview = '',
    required this.createdAt,
    required this.lastModified,
    this.isPinned = false,
    this.colorHex = 0xFF2A2A40,
  });

  factory Note.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Note(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      plainTextPreview: data['plainTextPreview'] ?? data['content'] ?? '', // Fallback to content for older notes
      createdAt: data['timestamp'] ?? data['createdAt'] ?? Timestamp.now(),
      lastModified: data['lastModified'] ?? Timestamp.now(),
      isPinned: data['isPinned'] ?? false,
      colorHex: data['colorHex'] ?? 0xFF2A2A40,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'plainTextPreview': plainTextPreview,
      'timestamp': createdAt,
      'lastModified': lastModified,
      'isPinned': isPinned,
      'colorHex': colorHex,
    };
  }
}
