import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

import '../models/diary_entry.dart';

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
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;

  // Speech-to-text
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _autoRestart = true;

  PermissionStatus _permissionStatus = PermissionStatus.denied;
  String _dictationBuffer = '';

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone permission required")),
      );
      return;
    }

    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' && _isListening && _autoRestart) {
          _speech.stop();
          Future.delayed(const Duration(milliseconds: 300), _listen);
        }
      },
      onError: (error) {
        debugPrint("Speech error: $error");
        _isListening = false;
      },
    );

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _speech.stop();
    _contentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _listen() async {
    if (!_speechAvailable || _permissionStatus != PermissionStatus.granted) return;

    if (!_isListening) {
      setState(() => _isListening = true);

      _autoRestart = true;
      _dictationBuffer = _contentController.text;

      await _speech.listen(
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
        onResult: (val) {
          if (!val.finalResult) return;

          _dictationBuffer =
              (_dictationBuffer + ' ' + val.recognizedWords).trim();

          _contentController.value = TextEditingValue(
            text: _dictationBuffer,
            selection:
                TextSelection.collapsed(offset: _dictationBuffer.length),
          );
        },
      );
    } else {
      _autoRestart = false;
      setState(() => _isListening = false);
      await _speech.stop();
    }
  }

  Future<void> _saveEntry() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final diaryRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('diary');

    final now = Timestamp.now();

    try {
      if (widget.entry == null) {
        await diaryRef.add({
          'content': content,
          'createdAt': now,
          'lastModified': now,
        });
      } else {
        await diaryRef.doc(widget.entry!.id).update({
          'content': content,
          'lastModified': now,
        });
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving diary entry: $e")),
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
        content: const Text("This action cannot be undone."),
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
          .collection('diary')
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
        title: Text(
          widget.entry == null ? "New Diary Entry" : "Edit Diary Entry",
        ),
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
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: "Write your diary entry...",
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            IconButton(
              iconSize: 32,
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              color:
                  _isListening ? Colors.red : Theme.of(context).primaryColor,
              onPressed: _listen,
            ),
          ],
        ),
      ),
    );
  }
}
