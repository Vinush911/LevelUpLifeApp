import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/diary_entry.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class EditDiaryEntryScreen extends StatefulWidget {
  final String uid;
  final DiaryEntry? entry;

  const EditDiaryEntryScreen({
    super.key,
    required this.uid,
    this.entry,
  });

  @override
  State<EditDiaryEntryScreen> createState() => _EditDiaryEntryScreenState();
}

class _EditDiaryEntryScreenState extends State<EditDiaryEntryScreen> {
  final _contentController = TextEditingController();
  bool _isLoading = false;

  // Speech-to-text
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  String _dictationBuffer = '';
  bool _autoRestart = true;


  @override
  void initState() {
    super.initState();

    if (widget.entry != null) {
      _contentController.text = widget.entry!.content;
    }

    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _permissionStatus = await Permission.microphone.request();

    if (_permissionStatus != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission required")),
        );
      }
      return;
    }

    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' && _isListening && _autoRestart) {
          _speech.stop();
          _listen(); // 🔁 restart automatically
        }
      },
      onError: (error) => debugPrint("Speech error: $error"),
    );


    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _speech.stop();
    _contentController.dispose();
    super.dispose();
  }

  void _listen() {
    if (!_speechAvailable || _permissionStatus != PermissionStatus.granted) return;

    if (!_isListening) {
      setState(() => _isListening = true);

      _autoRestart = true;
      _dictationBuffer = _contentController.text;

      _speech.listen(
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
        onResult: (val) {
          if (!val.finalResult) return;

          setState(() {
            _dictationBuffer =
                (_dictationBuffer + ' ' + val.recognizedWords).trim();

            _contentController.text = _dictationBuffer;
            _contentController.selection = TextSelection.fromPosition(
              TextPosition(offset: _contentController.text.length),
            );
          });
        },
      );
    } else {
      _autoRestart = false;
      setState(() => _isListening = false);
      _speech.stop();
    }
  }


  Future<void> _saveEntry() async {
    // STOP voice input before saving
    if (_isListening) {
      _autoRestart = false;
      _speech.stop();
      _isListening = false;
    }

    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);

    final diaryRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('diary_entries');

    final now = Timestamp.now();

    try {
      if (widget.entry == null) {
        // NEW ENTRY
        await diaryRef.add({
          'content': content,
          'timestamp': now,
          'lastModified': now,
        });
        // ensures queued writes are registered
        await FirebaseFirestore.instance.waitForPendingWrites();
      } else {
        // UPDATE ENTRY
        await diaryRef.doc(widget.entry!.id).update({
          'content': content,
          'lastModified': now,
        });
      }

      if (!mounted) return;

      Navigator.pop(context); // success
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save diary entry")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _deleteEntry() async {
    if (widget.entry == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Diary Entry"),
        content: const Text("Are you sure you want to delete this entry?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('diary_entries')
          .doc(widget.entry!.id)
          .delete();

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? "New Diary Entry" : "Edit Diary Entry"),
        actions: [
          if (widget.entry != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isLoading ? null : _deleteEntry,
            ),
          IconButton(
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveEntry,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: "Write your diary entry...",
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              iconSize: 32,
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              color: _isListening
                  ? Colors.red
                  : Theme.of(context).colorScheme.secondary,
              onPressed: _listen,
            ),
          ],
        ),
      ),
    );
  }
}
