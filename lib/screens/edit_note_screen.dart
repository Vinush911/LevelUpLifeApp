import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../models/note.dart';

class EditNoteScreen extends StatefulWidget {
  final String uid;
  final Note? note;

  const EditNoteScreen({super.key, required this.uid, this.note});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  late TextEditingController _titleController;
  late quill.QuillController _quillController;
  late FocusNode _editorFocusNode;
  late int _selectedColor;
  bool _isPinned = false;
  bool _showFormattingToolbar = false;
  
  Timer? _debounce;
  String? _currentNoteId;

  @override
  void initState() {
    super.initState();
    _editorFocusNode = FocusNode();
    _currentNoteId = widget.note?.id;
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _selectedColor = widget.note?.colorHex ?? 0xFF2A2A40;
    _isPinned = widget.note?.isPinned ?? false;

    // Load rich text from JSON delta, or fallback to plain text migration
    quill.Document document;
    if (widget.note != null && widget.note!.content.isNotEmpty) {
      try {
        final json = jsonDecode(widget.note!.content);
        document = quill.Document.fromJson(json);
      } catch (e) {
        // Migration: Old note is plain text! Insert it into a new document.
        document = quill.Document()..insert(0, widget.note!.content);
      }
    } else {
      document = quill.Document();
    }

    _quillController = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _titleController.addListener(_onTextChanged);
    _quillController.document.changes.listen((_) => _onTextChanged());

    _editorFocusNode.addListener(() {
      if (_editorFocusNode.hasFocus && _showFormattingToolbar) {
        setState(() => _showFormattingToolbar = false);
      }
    });
  }

  void _onTextChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      _saveNote();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Final save to catch any lingering edits immediately before pop
    if (_titleController.text.isNotEmpty || !_quillController.document.isEmpty()) {
      _saveNote();
    }
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final plainText = _quillController.document.toPlainText().trim();
    final jsonDelta = jsonEncode(_quillController.document.toDelta().toJson());

    // If both are empty and we haven't created a document yet, do nothing.
    if (title.isEmpty && plainText.isEmpty && _currentNoteId == null) return;

    final firestore = FirebaseFirestore.instance;
    final notesRef = firestore.collection('users').doc(widget.uid).collection('notes');

    try {
      if (_currentNoteId == null) {
        // Create new note
        final docRef = await notesRef.add({
          'title': title,
          'content': jsonDelta, // Store Rich Text JSON
          'plainTextPreview': plainText, // Store raw text for grid cards
          'timestamp': FieldValue.serverTimestamp(),
          'lastModified': FieldValue.serverTimestamp(),
          'isPinned': _isPinned,
          'colorHex': _selectedColor,
        });
        _currentNoteId = docRef.id;
      } else {
        // Update existing note
        await notesRef.doc(_currentNoteId).update({
          'title': title,
          'content': jsonDelta,
          'plainTextPreview': plainText,
          'lastModified': FieldValue.serverTimestamp(),
          'isPinned': _isPinned,
          'colorHex': _selectedColor,
        });
      }
    } catch (e) {
      debugPrint('Error auto-saving note: $e');
    }
  }

  void _toggleCheckList() {
    final format = _quillController.getSelectionStyle().attributes[quill.Attribute.list.key];
    if (format?.value == quill.Attribute.unchecked.value || format?.value == quill.Attribute.checked.value) {
      _quillController.formatSelection(quill.Attribute.clone(quill.Attribute.list, null));
    } else {
      _quillController.formatSelection(quill.Attribute.unchecked);
    }
  }

  Future<void> _confirmDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text("Delete Note?", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this note? This action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("Cancel", style: TextStyle(color: Colors.white54))
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      )
    );
    if (result == true && _currentNoteId != null) {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('notes').doc(_currentNoteId).delete();
      if (mounted) Navigator.of(context).pop();
    } else if (result == true && _currentNoteId == null) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _showColorPicker() {
    FocusScope.of(context).unfocus(); // Hide keyboard cleanly
    final colors = [
      0xFF2A2A40, // Default Dark
      0xFF5C2C35, // Burgundy
      0xFF234438, // Forest
      0xFF2A3C5A, // Ocean
      0xFF5A3E26, // Bronze
      0xFF4A235A, // Royal
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 140,
        decoration: const BoxDecoration(
          color: Color(0xFF16213E), // Standard panel color
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: colors.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (context, index) {
            final color = colors[index];
            final isSelected = _selectedColor == color;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedColor = color);
                _saveNote();
                Navigator.pop(ctx);
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? Colors.amber : Colors.white24, width: isSelected ? 3 : 1),
                  boxShadow: isSelected ? [BoxShadow(color: Color(color).withOpacity(0.8), blurRadius: 8)] : null,
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.amber) : null,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(_selectedColor),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _isPinned ? Colors.white : Colors.white70,
            ),
            tooltip: _isPinned ? "Unpin" : "Pin",
            onPressed: () {
              setState(() => _isPinned = !_isPinned);
              _saveNote();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [


              // --- TITLE EDITOR ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                  decoration: const InputDecoration(
                    hintText: "Title",
                    hintStyle: TextStyle(color: Colors.white54, fontSize: 26, fontWeight: FontWeight.bold),
                    border: InputBorder.none,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                ),
              ),

              // --- CONTENT EDITOR (WYSIWYG) ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: quill.QuillEditor.basic(
                    controller: _quillController,
                    focusNode: _editorFocusNode,
                    config: quill.QuillEditorConfig(
                      placeholder: "Start writing your rich note here...",
                      customStyles: quill.DefaultStyles(
                        placeHolder: quill.DefaultTextBlockStyle(
                          const TextStyle(color: Colors.white54, fontSize: 17),
                          const quill.HorizontalSpacing(0, 0),
                          const quill.VerticalSpacing(0, 0),
                          const quill.VerticalSpacing(0, 0),
                          null,
                        ),
                        paragraph: quill.DefaultTextBlockStyle(
                          const TextStyle(fontSize: 17, color: Colors.white70, height: 1.6),
                          const quill.HorizontalSpacing(0, 0),
                          const quill.VerticalSpacing(0, 0),
                          const quill.VerticalSpacing(0, 0),
                          null,
                        ),
                        lists: quill.DefaultListBlockStyle(
                          const TextStyle(fontSize: 17, color: Colors.white70, height: 1.6),
                          const quill.HorizontalSpacing(0, 0),
                          const quill.VerticalSpacing(0, 0),
                          const quill.VerticalSpacing(0, 0),
                          null,
                          null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // --- BOTTOM SECTION (PINNED ABOVE KEYBOARD) ---
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- RICH TEXT TOOLBAR (ONLY WHEN TOGGLED) ---
                    if (_showFormattingToolbar)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0, left: 8.0, right: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: quill.QuillSimpleToolbar(
                                controller: _quillController,
                                config: const quill.QuillSimpleToolbarConfig(
                                  showFontFamily: false,
                                  showFontSize: true,
                                  showBoldButton: true,
                                  showItalicButton: true,
                                  showUnderLineButton: true,
                                  showStrikeThrough: true,
                                  showColorButton: false,
                                  showBackgroundColorButton: true,
                                  showListNumbers: true,
                                  showListBullets: true,
                                  showListCheck: false, // Removed as requested
                                  showSearchButton: false,
                                  showInlineCode: false,
                                  showCodeBlock: false,
                                  showQuote: false,
                                  showLink: false,
                                  showIndent: false,
                                  showUndo: false,
                                  showRedo: false,
                                  showAlignmentButtons: false,
                                  showDirection: false,
                                  showHeaderStyle: false,
                                  showClearFormat: false,
                                  showClipboardCopy: false,
                                  showClipboardCut: false,
                                  showClipboardPaste: false,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70),
                              onPressed: () {
                                setState(() => _showFormattingToolbar = false);
                                _editorFocusNode.requestFocus();
                              },
                            )
                          ],
                        ),
                      ),
                    
                    // --- SETTINGS TOOLBAR (DEFAULT STATE) ---
                    if (!_showFormattingToolbar)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.text_format, color: Colors.white70),
                                  onPressed: () {
                                    setState(() => _showFormattingToolbar = true);
                                    _editorFocusNode.unfocus(); // Close keyboard
                                  },
                                  tooltip: "Format Text",
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check_box_outlined, color: Colors.white70),
                                  onPressed: _toggleCheckList,
                                  tooltip: "Add Checklist",
                                ),
                                IconButton(
                                  icon: const Icon(Icons.palette_outlined, color: Colors.white70),
                                  onPressed: _showColorPicker,
                                  tooltip: "Change Color",
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.white70),
                              onPressed: _confirmDelete,
                              tooltip: "Delete",
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}