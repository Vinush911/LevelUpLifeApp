import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/timetable_entry.dart';
import '../services/notification_service.dart'; // <<<--- ADD THIS IMPORT

class EditTimetableEntryScreen extends StatefulWidget {
  final String uid;
  final TimetableEntry? entry; // Null if creating a new entry

  const EditTimetableEntryScreen({super.key, required this.uid, this.entry});

  @override
  State<EditTimetableEntryScreen> createState() => _EditTimetableEntryScreenState();
}

class _EditTimetableEntryScreenState extends State<EditTimetableEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late List<bool> _selectedDays;
  late bool _reminderEnabled;
  late int _reminderOffset;

  final List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<int> _reminderOffsets = [5, 10, 15, 30, 60];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final isEditing = widget.entry != null;

    _titleController = TextEditingController(text: isEditing ? widget.entry!.title : '');
    _startTime = isEditing ? widget.entry!.startTime : const TimeOfDay(hour: 9, minute: 0);
    _endTime = isEditing ? widget.entry!.endTime : const TimeOfDay(hour: 10, minute: 0);
    _reminderEnabled = isEditing ? widget.entry!.reminderEnabled : false;
    _reminderOffset = isEditing ? widget.entry!.reminderTimeOffset : 5;

    _selectedDays = List.generate(7, (index) {
      if (isEditing) {
        return widget.entry!.repeatDays.contains(_dayLabels[index]);
      }
      return false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
        // Auto-adjust end time if it's before the new start time
        if (TimetableEntry.timeOfDayToMinutes(_endTime) <= TimetableEntry.timeOfDayToMinutes(_startTime)) {
          final newEndMinutes = TimetableEntry.timeOfDayToMinutes(_startTime) + 60;
          _endTime = TimeOfDay(hour: newEndMinutes ~/ 60, minute: newEndMinutes % 60);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null && picked != _endTime) {
      // Validate that end time is after start time
      if (TimetableEntry.timeOfDayToMinutes(picked) <= TimetableEntry.timeOfDayToMinutes(_startTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("End time must be after start time."), backgroundColor: Colors.orange),
        );
      } else {
        setState(() {
          _endTime = picked;
        });
      }
    }
  }

  // --- vvv THIS FUNCTION IS UPDATED vvv ---
  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.every((day) => day == false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one day to repeat."), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    final repeatDays = <String>[];
    for (int i = 0; i < _selectedDays.length; i++) {
      if (_selectedDays[i]) {
        repeatDays.add(_dayLabels[i]);
      }
    }

    try {
      final collectionRef = FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('timetable_entries');

      // Create a temporary entry object to pass to the notification service
      // We need to do this *before* saving to get all the data.
      final tempEntry = TimetableEntry(
        id: widget.entry?.id ?? '', // ID will be blank for new entries
        title: _titleController.text,
        startTimeMinutes: TimetableEntry.timeOfDayToMinutes(_startTime),
        endTimeMinutes: TimetableEntry.timeOfDayToMinutes(_endTime),
        repeatDays: repeatDays,
        reminderEnabled: _reminderEnabled,
        reminderTimeOffset: _reminderOffset,
        notificationId: widget.entry?.notificationId, // Pass the OLD ID for cancellation
      );

      // Schedule (or cancel) the notification
      // This will cancel the old one and schedule a new one if enabled.
      final newNotificationId = await NotificationService.instance.scheduleTimetableEntry(tempEntry);

      // Now, build the final data map to save to Firestore
      final entryData = {
        'title': tempEntry.title,
        'startTimeMinutes': tempEntry.startTimeMinutes,
        'endTimeMinutes': tempEntry.endTimeMinutes,
        'repeatDays': tempEntry.repeatDays,
        'reminderEnabled': tempEntry.reminderEnabled,
        'reminderTimeOffset': tempEntry.reminderTimeOffset,
        'notificationId': _reminderEnabled ? newNotificationId : null, // Store the new ID
      };

      if (widget.entry == null) {
        // Create new
        await collectionRef.add(entryData);
      } else {
        // Update existing
        await collectionRef.doc(widget.entry!.id).update(entryData);
      }

      if (mounted) Navigator.pop(context);

    } catch (e) {
      debugPrint("Error saving entry: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving entry: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // --- ^^^ THIS FUNCTION IS UPDATED ^^^ ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? "New Timetable Entry" : "Edit Entry"),
        actions: [
          IconButton(
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveEntry,
            tooltip: "Save Entry",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Title"),
                validator: (v) => v == null || v.isEmpty ? "Please enter a title" : null,
              ),
              const SizedBox(height: 24),

              // --- Time Pickers ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTimeChip("Start Time", _startTime, _pickStartTime),
                  const Icon(Icons.arrow_forward),
                  _buildTimeChip("End Time", _endTime, _pickEndTime),
                ],
              ),
              const SizedBox(height: 24),

              // --- Day Selector ---
              const Text("Repeat On:", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Center(
                child: ToggleButtons(
                  isSelected: _selectedDays,
                  onPressed: (index) {
                    setState(() {
                      _selectedDays[index] = !_selectedDays[index];
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  children: _dayLabels.map((day) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(day),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // --- Reminder Settings ---
              const Text("Reminder:", style: TextStyle(fontSize: 16)),
              SwitchListTile(
                title: const Text("Enable Reminder"),
                value: _reminderEnabled,
                onChanged: (val) => setState(() => _reminderEnabled = val),
              ),
              if (_reminderEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButtonFormField<int>(
                    value: _reminderOffset,
                    items: _reminderOffsets.map((minutes) => DropdownMenuItem(
                      value: minutes,
                      child: Text("$minutes minutes before"),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _reminderOffset = val);
                      }
                    },
                    decoration: const InputDecoration(labelText: "Reminder Time"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChip(String label, TimeOfDay time, VoidCallback onTap) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        ActionChip(
          label: Text(time.format(context), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          onPressed: onTap,
          avatar: const Icon(Icons.edit_calendar_outlined),
        ),
      ],
    );
  }
}