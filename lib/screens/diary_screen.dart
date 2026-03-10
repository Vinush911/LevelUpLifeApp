import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // 1️⃣ Import Provider
import '../models/diary_entry.dart';
import '../utils/firestore_sync_notifier.dart'; // 2️⃣ Import Sync Notifier
import 'edit_diary_entry_screen.dart';

class DiaryScreen extends StatelessWidget {
  final String uid;
  const DiaryScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary'),
        // Test notification buttons removed from here
      ),
      body: Column(
        children: [
          // 3️⃣ Offline Banner (Added at the top of the body)
          Consumer<FirestoreSyncNotifier>(
            builder: (context, sync, _) {
              if (sync.isSynced) return const SizedBox.shrink();

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.orange,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      "Offline – viewing cached entries",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),

          // 4️⃣ The List of Entries (Wrapped in Expanded)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                    // Ensure your DiaryEntry model handles the document snapshot correctly
                    final entry = DiaryEntry.fromFirestore(entryDoc);

                    return ListTile(
                      title: Text(
                        // Check for null timestamp in case of immediate offline write
                        entry.timestamp != null
                            ? DateFormat.yMMMd().add_jm().format(entry.timestamp!.toDate())
                            : "Just now...",
                      ),
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
          ),
        ],
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