import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../models/reminder.dart';
import '../../providers/notes_provider.dart';
import 'widgets/note_actions.dart';
import 'widgets/reminder_form_section.dart';

class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({super.key, this.note});

  /// اگر null باشد، فرم در حالت «افزودن یادداشت جدید» است.
  final Note? note;

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagController;
  late bool _isPinned;

  bool _reminderEnabled = false;
  DateTime _reminderDateTime = DateTime.now().add(const Duration(hours: 1));
  ReminderRepeatType _repeatType = ReminderRepeatType.none;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _tagController = TextEditingController(text: note?.tag ?? '');
    _isPinned = note?.isPinned ?? false;

    if (note?.id != null) {
      context.read<NotesProvider>().getReminderForNote(note!.id!).then((reminder) {
        if (!mounted || reminder == null) return;
        setState(() {
          _reminderEnabled = true;
          _reminderDateTime = reminder.dateTime;
          _repeatType = reminder.repeatType;
        });
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final provider = context.read<NotesProvider>();
    final reminder = _reminderEnabled
        ? Reminder(title: title, dateTime: _reminderDateTime, repeatType: _repeatType)
        : null;

    if (_isEditing) {
      await provider.updateNote(
        widget.note!.copyWith(
          title: title,
          content: _contentController.text.trim(),
          tag: _tagController.text.trim(),
          isPinned: _isPinned,
        ),
        reminder: reminder,
      );
    } else {
      await provider.addNote(
        title: title,
        content: _contentController.text.trim(),
        tag: _tagController.text.trim(),
        isPinned: _isPinned,
        reminder: reminder,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDeleteNoteConfirmation(context);
    if (!confirmed || !mounted) return;
    await context.read<NotesProvider>().deleteNote(widget.note!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final existingTags = context.watch<NotesProvider>().allTags;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'ویرایش یادداشت' : 'یادداشت جدید'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'حذف یادداشت',
              onPressed: _delete,
            ),
          IconButton(icon: const Icon(Icons.check), tooltip: 'ذخیره', onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'عنوان', border: OutlineInputBorder()),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'عنوان نمی‌تواند خالی باشد' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'متن یادداشت',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 5,
              maxLines: 12,
              textAlignVertical: TextAlignVertical.top,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tagController,
              decoration: const InputDecoration(
                labelText: 'تگ (اختیاری)',
                border: OutlineInputBorder(),
              ),
            ),
            if (existingTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: existingTags
                    .map(
                      (tag) => ActionChip(
                        label: Text(tag),
                        onPressed: () => setState(() => _tagController.text = tag),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('سنجاق کردن'),
              secondary: const Icon(Icons.push_pin_outlined),
              value: _isPinned,
              onChanged: (value) => setState(() => _isPinned = value),
            ),
            ReminderFormSection(
              enabled: _reminderEnabled,
              dateTime: _reminderDateTime,
              repeatType: _repeatType,
              onEnabledChanged: (value) => setState(() => _reminderEnabled = value),
              onDateTimeChanged: (value) => setState(() => _reminderDateTime = value),
              onRepeatTypeChanged: (value) => setState(() => _repeatType = value),
            ),
          ],
        ),
      ),
    );
  }
}
