import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/note.dart';
import 'edit_note_screen.dart';

class NotesScreen extends StatelessWidget {
  final String uid;
  const NotesScreen({super.key, required this.uid});

  // --- 🛠️ HELPER METHOD: Builds the ultra-clean Google Keep style Note Card ---
  Widget _buildNoteCard(BuildContext context, DocumentSnapshot noteDoc) {
    final note = Note.fromFirestore(noteDoc);
    final isPinned = note.isPinned;
    final noteColor = Color(note.colorHex);

    return Container(
      decoration: BoxDecoration(
        color: noteColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05), // Extremely subtle border
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => EditNoteScreen(uid: uid, note: note)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.title.isNotEmpty || isPinned)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPinned)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.push_pin, color: Colors.white.withOpacity(0.9), size: 16),
                        ),
                    ],
                  ),
                if (note.title.isNotEmpty && note.plainTextPreview.isNotEmpty)
                  const SizedBox(height: 8),
                if (note.plainTextPreview.isNotEmpty)
                  Text(
                    note.plainTextPreview,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 15,
                      height: 1.5,
                    ),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16213E), // Clean dark background
      appBar: AppBar(
        title: const Text("Notes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notes')
            .orderBy('lastModified', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note, size: 80, color: Colors.grey.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text("Notes you add appear here", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                ],
              )
            );
          }

          final sortedNotes = snapshot.data!.docs.toList();
          sortedNotes.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>? ?? {};
            final bData = b.data() as Map<String, dynamic>? ?? {};
            final aPinned = aData['isPinned'] as bool? ?? false;
            final bPinned = bData['isPinned'] as bool? ?? false;

            if (aPinned && !bPinned) return -1;
            if (!aPinned && bPinned) return 1;
            
            final aTime = (aData['lastModified'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = (bData['lastModified'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          return MasonryGridView.count(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
            crossAxisCount: 2,
            mainAxisSpacing: 10.0,
            crossAxisSpacing: 10.0,
            physics: const BouncingScrollPhysics(),
            itemCount: sortedNotes.length,
            itemBuilder: (context, index) {
              return _buildNoteCard(context, sortedNotes[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditNoteScreen(uid: uid),
            ),
          );
        },
        backgroundColor: const Color(0xFF2A2A40), // Premium dark button
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.1))),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }
}