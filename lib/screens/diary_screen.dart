import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import 'edit_diary_entry_screen.dart'; // We'll create this next

class DiaryScreen extends StatelessWidget {
  final String uid;
  const DiaryScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Diary"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('diary_entries')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No diary entries yet."));
          }

          final entries = snapshot.data!.docs;

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entryDoc = entries[index];
              final entry = DiaryEntry.fromFirestore(entryDoc);
              return ListTile(
                title: Text(DateFormat.yMMMd().add_jm().format(entry.timestamp.toDate())),
                subtitle: Text(
                  entry.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EditDiaryEntryScreen(uid: uid, entry: entry),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditDiaryEntryScreen(uid: uid), // Pass null for new entry
            ),
          );
        },
        tooltip: 'Add Diary Entry',
        child: const Icon(Icons.add),
      ),
    );
  }
}
