import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/diary_entry.dart';
// --- NEW IMPORTS ---
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class EditDiaryEntryScreen extends StatefulWidget {
  final String uid;
  final DiaryEntry? entry; // Null if creating a new entry

  const EditDiaryEntryScreen({super.key, required this.uid, this.entry});

  @override
  State<EditDiaryEntryScreen> createState() => _EditDiaryEntryScreenState();
}

class _EditDiaryEntryScreenState extends State<EditDiaryEntryScreen> {
  final _contentController = TextEditingController();
  bool _isLoading = false;

  // --- NEW: Speech-to-Text State ---
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _textBuffer = ''; // To hold text while listening
  bool _speechAvailable = false;
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _contentController.text = widget.entry!.content;
    }
    _speech = stt.SpeechToText();
    _requestPermissionAndInitSpeech();
  }

  // --- NEW: Request permission and initialize speech ---
  Future<void> _requestPermissionAndInitSpeech() async {
    _permissionStatus = await Permission.microphone.request();
    if (_permissionStatus == PermissionStatus.granted) {
      bool available = await _speech.initialize(
        onStatus: (val) => debugPrint('onStatus: $val'),
        onError: (val) => debugPrint('onError: $val'),
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


  @override
  void dispose() {
    _contentController.dispose();
    _speech.stop(); // Ensure speech is stopped when screen is disposed
    super.dispose();
  }

  Future<void> _saveEntry() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);

    final firestore = FirebaseFirestore.instance;
    final collectionRef = firestore.collection('users').doc(widget.uid).collection('diary_entries');

    try {
      if (widget.entry == null) {
        // Create new entry
        await collectionRef.add({
          'content': content,
          'timestamp': Timestamp.now(),
        });
      } else {
        // Update existing entry
        await collectionRef.doc(widget.entry!.id).update({
          'content': content,
          'timestamp': Timestamp.now(), // Optionally update timestamp on edit
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error saving diary entry: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving entry: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        final currentCursorPos = _contentController.selection.baseOffset;
        _textBuffer = _contentController.text; // Store current text

        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            // Insert recognized words at the cursor position
            final recognizedWords = val.recognizedWords;
            if (recognizedWords.isNotEmpty) {
              // Get text before and after cursor
              final textBeforeCursor = currentCursorPos >= 0 ? _textBuffer.substring(0, currentCursorPos) : '';
              final textAfterCursor = currentCursorPos >= 0 && currentCursorPos < _textBuffer.length ? _textBuffer.substring(currentCursorPos) : '';

              // Combine parts with new words
              _contentController.text = '$textBeforeCursor$recognizedWords $textAfterCursor';

              // Move cursor to the end of inserted text
              _contentController.selection = TextSelection.fromPosition(
                  TextPosition(offset: currentCursorPos + recognizedWords.length + 1) // +1 for the space
              );
              // Update buffer for subsequent recognitions in this session
              _textBuffer = _contentController.text;
            }
          }),
        );
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
        title: Text(widget.entry == null ? "New Diary Entry" : "Edit Entry"),
        actions: [
          IconButton(
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveEntry,
            tooltip: "Save Entry",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column( // Use Column to add button below TextField
          children: [
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: "Write about your day...",
                  border: InputBorder.none,
                ),
                autofocus: true,
              ),
            ),
            // --- NEW: Microphone Button ---
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: IconButton(
                icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                color: _isListening ? Colors.redAccent : Theme.of(context).iconTheme.color,
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

