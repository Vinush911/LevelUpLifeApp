import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
// --- NEW IMPORTS ---
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';


class EditNoteScreen extends StatefulWidget {
  final String uid;
  final Note? note; // Null if creating a new note

  const EditNoteScreen({super.key, required this.uid, this.note});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;

  // --- NEW: Speech-to-Text State ---
  late stt.SpeechToText _speech;
  bool _isListening = false;
  // String _textBuffer = ''; // --- REMOVED: No longer needed with append logic ---
  bool _speechAvailable = false;
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  // ---

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
    }
    // --- NEW: Init speech ---
    _speech = stt.SpeechToText();
    _requestPermissionAndInitSpeech();
    // ---
  }

  // --- NEW: Request permission and initialize speech ---
  Future<void> _requestPermissionAndInitSpeech() async {
    _permissionStatus = await Permission.microphone.request();
    if (_permissionStatus == PermissionStatus.granted) {
      bool available = await _speech.initialize(
          onStatus: (val) => debugPrint('onStatus: $val'),
          onError: (val) { // --- ADDED: Basic error logging ---
            debugPrint('onError: $val');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Speech recognition error: ${val.errorMsg}")),
              );
              setState(() => _isListening = false); // Stop listening on error
            }
          }
      );
      if (mounted) {
        setState(() => _speechAvailable = available);
      }
    } else {
      debugPrint("Microphone permission denied");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission is required for voice input.")),
        );
      }
    }
  }
  // ---

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _speech.stop(); // --- NEW: Stop speech on dispose ---
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (content.isEmpty && title.isEmpty) return; // Don't save empty notes

    setState(() => _isLoading = true);

    final firestore = FirebaseFirestore.instance;
    final collectionRef = firestore.collection('users').doc(widget.uid).collection('notes');
    final now = Timestamp.now();

    try {
      if (widget.note == null) {
        // Create new note
        await collectionRef.add({
          'title': title,
          'content': content,
          'createdAt': now,
          'lastModified': now,
        });
      } else {
        // Update existing note
        await collectionRef.doc(widget.note!.id).update({
          'title': title,
          'content': content,
          'lastModified': now,
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error saving note: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving note: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNote() async {
    if (widget.note == null) return; // Cannot delete if not editing

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Note?"),
        content: const Text("Are you sure you want to permanently delete this note?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('notes')
            .doc(widget.note!.id)
            .delete();
        if (mounted) Navigator.pop(context); // Pop after successful deletion
      } catch (e) {
        debugPrint("Error deleting note: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting note: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- NEW: Speech control methods ---
  void _listen() async {
    if (!_speechAvailable || _permissionStatus != PermissionStatus.granted) {
      _requestPermissionAndInitSpeech(); // Try again if not ready
      return;
    }
    if (!_isListening) {
      bool available = await _speech.initialize(); // Re-initialize just in case
      if (available) {
        // final currentCursorPos = _contentController.selection.baseOffset; // --- REMOVED ---
        // _textBuffer = _contentController.text; // --- REMOVED ---

        setState(() => _isListening = true);
        _speech.listen(
          listenFor: const Duration(minutes: 1), // --- ADDED: Listen for longer ---
          pauseFor: const Duration(seconds: 5), // --- ADDED: Pause if user stops talking ---
          onResult: (val) => setState(() {
            // --- MODIFIED: Simpler append logic ---
            // Append the newly recognized words to the current text.
            _contentController.text = _contentController.text + (val.recognizedWords.isNotEmpty ? ' ${val.recognizedWords}' : '');
            // Move cursor to the end after appending
            _contentController.selection = TextSelection.fromPosition(
                TextPosition(offset: _contentController.text.length)
            );
            // --- END MODIFICATION ---
          }),
          // --- ADDED: Handle end of listening ---
          onSoundLevelChange: null, // Can add visualizer later if needed
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation, // Adjust listen mode if needed
        );
      } else {
        // --- ADDED: Handle case where initialization fails right before listening ---
        debugPrint("Speech recognition not available.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Speech recognition is currently unavailable.")),
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? "New Note" : "Edit Note"),
        actions: [
          if (widget.note != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isLoading ? null : _deleteNote,
              tooltip: "Delete Note",
            ),
          IconButton(
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveNote,
            tooltip: "Save Note",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: "Title",
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: "Write your note...",
                  border: InputBorder.none,
                ),
                autofocus: widget.note == null,
              ),
            ),
            // --- NEW: Microphone Button ---
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: IconButton(
                iconSize: 32, // --- Make button slightly larger ---
                icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                color: _isListening ? Colors.redAccent : Theme.of(context).colorScheme.secondary, // Use theme color
                tooltip: _isListening ? 'Stop Listening' : 'Start Voice Input',
                onPressed: _listen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

