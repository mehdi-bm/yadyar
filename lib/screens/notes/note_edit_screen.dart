import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../models/reminder.dart';
import '../../providers/notes_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/palette_color_picker.dart';
import 'widgets/note_actions.dart';
import 'widgets/reminder_form_section.dart';

enum _EditorAction { share, copy, archive, delete }

class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({super.key, this.note, this.startWithReminder = false});

  /// اگر null باشد، فرم در حالت «افزودن یادداشت جدید» است.
  final Note? note;

  /// برای یادداشت جدید: بخش یادآور از ابتدا روشن باشد (میان‌بر «یادآور جدید»).
  final bool startWithReminder;

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagController;
  late bool _isPinned;
  int? _colorValue;

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
    _contentController.addListener(() => setState(() {}));
    _tagController = TextEditingController(text: note?.tag ?? '');
    _isPinned = note?.isPinned ?? false;
    _colorValue = note?.colorValue;
    _reminderEnabled = note == null && widget.startWithReminder;

    if (note?.id != null) {
      context.read<NotesProvider>().getReminderForNote(note!.id!).then((
        reminder,
      ) {
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
        ? Reminder(
            title: title,
            dateTime: _reminderDateTime,
            repeatType: _repeatType,
          )
        : null;

    if (_isEditing) {
      await provider.updateNote(
        widget.note!.copyWith(
          title: title,
          content: _contentController.text.trim(),
          tag: _tagController.text.trim(),
          isPinned: _isPinned,
          colorValue: _colorValue,
          clearColor: _colorValue == null,
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
        colorValue: _colorValue,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onAction(_EditorAction action) async {
    final note = widget.note!;
    switch (action) {
      case _EditorAction.share:
        await runNoteAction(context, note, NoteAction.share);
      case _EditorAction.copy:
        await runNoteAction(context, note, NoteAction.copy);
      case _EditorAction.archive:
        final navigator = Navigator.of(context);
        await runNoteAction(context, note, NoteAction.archive);
        navigator.pop();
      case _EditorAction.delete:
        final navigator = Navigator.of(context);
        await trashNoteWithUndo(context, note);
        navigator.pop();
    }
  }

  PopupMenuItem<_EditorAction> _menuItem(
    _EditorAction value,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existingTags = context.watch<NotesProvider>().allTags;
    final theme = Theme.of(context);
    final content = _contentController.text.trim();
    final words = content.isEmpty ? 0 : content.split(RegExp(r'\s+')).length;
    final isArchived = widget.note?.isArchived ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'ویرایش یادداشت' : 'یادداشت جدید'),
        actions: [
          if (_isEditing)
            PopupMenuButton<_EditorAction>(
              tooltip: 'گزینه‌های بیشتر',
              onSelected: _onAction,
              itemBuilder: (context) => [
                _menuItem(
                  _EditorAction.share,
                  Icons.share_outlined,
                  'اشتراک‌گذاری',
                ),
                _menuItem(_EditorAction.copy, Icons.copy_outlined, 'کپی متن'),
                _menuItem(
                  _EditorAction.archive,
                  isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  isArchived ? 'خروج از بایگانی' : 'بایگانی',
                ),
                _menuItem(
                  _EditorAction.delete,
                  Icons.delete_outline,
                  'حذف یادداشت',
                  color: theme.colorScheme.error,
                ),
              ],
            ),
          IconButton.filled(
            icon: const Icon(Icons.check),
            tooltip: 'ذخیره',
            onPressed: _save,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان',
                        prefixIcon: Icon(Icons.title_outlined),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'عنوان نمی‌تواند خالی باشد'
                          : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'متن یادداشت',
                        alignLabelWithHint: true,
                      ),
                      minLines: 5,
                      maxLines: 14,
                      textAlignVertical: TextAlignVertical.top,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${formatNumber(words)} کلمه • ${formatNumber(content.length)} نویسه',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        if (_isEditing)
                          Text(
                            'ویرایش: ${formatJalaliDateTime(widget.note!.updatedAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _tagController,
                      decoration: const InputDecoration(
                        labelText: 'تگ (اختیاری)',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    if (existingTags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: existingTags
                              .map(
                                (tag) => ActionChip(
                                  label: Text(tag),
                                  onPressed: () =>
                                      setState(() => _tagController.text = tag),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('سنجاق کردن'),
                      secondary: const Icon(Icons.push_pin_outlined),
                      value: _isPinned,
                      onChanged: (value) => setState(() => _isPinned = value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('رنگ یادداشت', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 10),
                    PaletteColorPicker(
                      selected: _colorValue,
                      allowNone: true,
                      onChanged: (value) => setState(() => _colorValue = value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ReminderFormSection(
              enabled: _reminderEnabled,
              dateTime: _reminderDateTime,
              repeatType: _repeatType,
              onEnabledChanged: (value) =>
                  setState(() => _reminderEnabled = value),
              onDateTimeChanged: (value) =>
                  setState(() => _reminderDateTime = value),
              onRepeatTypeChanged: (value) =>
                  setState(() => _repeatType = value),
            ),
          ],
        ),
      ),
    );
  }
}
