import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class EditNoteScreen extends StatefulWidget {
  final String uid;
  final Note? note;

  const EditNoteScreen({super.key, required this.uid, this.note});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  final _titleController = TextEditingController();
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

    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
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
          _listen(); // 🔁 auto-restart for continuous dictation
        }
      },
      onError: (error) => debugPrint("Speech error: $error"),
    );


    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _speech.stop();
    _titleController.dispose();
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
          if (!val.finalResult) return; // 🔑 ignore partials

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


  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) return;

    setState(() => _isLoading = true);

    final notesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('notes');

    final now = Timestamp.now();

    try {
      if (widget.note == null) {
        await notesRef.add({
          'title': title,
          'content': content,
          'createdAt': now,
          'lastModified': now,
        });
      } else {
        await notesRef.doc(widget.note!.id).update({
          'title': title,
          'content': content,
          'lastModified': now,
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving note: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNote() async {
    if (widget.note == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Note"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
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
          .collection('notes')
          .doc(widget.note!.id)
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
        title: Text(widget.note == null ? "New Note" : "Edit Note"),
        actions: [
          if (widget.note != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isLoading ? null : _deleteNote,
            ),
          IconButton(
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveNote,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
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
              ),
            ),
            IconButton(
              iconSize: 32,
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              color: _isListening ? Colors.red : Theme.of(context).colorScheme.secondary,
              onPressed: _listen,
            ),
          ],
        ),
      ),
    );
  }
}
