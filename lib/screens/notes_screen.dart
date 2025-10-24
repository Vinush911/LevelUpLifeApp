import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import 'edit_note_screen.dart'; // We'll create this next

class NotesScreen extends StatelessWidget {
  final String uid;
  const NotesScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notes"),
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notes yet."));
          }

          final notes = snapshot.data!.docs;

          // Using GridView for a different layout
          return GridView.builder(
            padding: const EdgeInsets.all(10.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // Two columns
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
              childAspectRatio: 0.8, // Adjust aspect ratio as needed
            ),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final noteDoc = notes[index];
              final note = Note.fromFirestore(noteDoc);
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EditNoteScreen(uid: uid, note: note),
                    ),
                  );
                },
                child: Card(
                  color: const Color(0xFF16213E),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title.isEmpty ? "Untitled Note" : note.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            note.content,
                            style: TextStyle(color: Colors.grey.shade400),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 5, // Limit lines shown in grid
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Edited: ${DateFormat.yMd().add_jm().format(note.lastModified.toDate())}",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditNoteScreen(uid: uid), // Pass null for new note
            ),
          );
        },
        tooltip: 'Add Note',
        child: const Icon(Icons.add),
      ),
    );
  }
}
