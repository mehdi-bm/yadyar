import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/note.dart';
import '../../../providers/notes_provider.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/palette_color_picker.dart';
import '../note_edit_screen.dart';

/// حذف دائمی (از «حذف‌شده‌ها»).
Future<bool> showDeleteNoteConfirmation(BuildContext context) {
  return showConfirmDialog(
    context,
    title: 'حذف برای همیشه',
    message:
        'این یادداشت و یادآور مرتبط با آن (در صورت وجود) برای همیشه حذف خواهد شد و قابل بازیابی نیست.',
    confirmLabel: 'حذف دائمی',
  );
}

enum NoteAction { edit, pin, archive, share, copy, duplicate, delete }

Future<void> openNoteEditor(BuildContext context, {Note? note}) {
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => NoteEditScreen(note: note)));
}

void _showUndoSnackBar(
  BuildContext context,
  String message,
  VoidCallback onUndo,
) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        // اسنک‌بار دارای action به‌طور پیش‌فرض خودکار بسته نمی‌شود (persist).
        persist: false,
        duration: const Duration(seconds: 4),
        showCloseIcon: true,
        action: SnackBarAction(label: 'بازگردانی', onPressed: onUndo),
      ),
    );
}

String _titleOf(Note note) => note.title.isEmpty ? 'یادداشت' : note.title;

/// انتقال به «حذف‌شده‌ها» با امکان بازگردانی فوری.
Future<void> trashNoteWithUndo(BuildContext context, Note note) async {
  final provider = context.read<NotesProvider>();
  await provider.moveToTrash(note);
  if (!context.mounted) return;
  _showUndoSnackBar(
    context,
    '«${_titleOf(note)}» به حذف‌شده‌ها منتقل شد',
    () => provider.restoreFromTrash(note),
  );
}

Future<void> archiveNoteWithUndo(BuildContext context, Note note) async {
  final provider = context.read<NotesProvider>();
  await provider.setArchived(note, true);
  if (!context.mounted) return;
  _showUndoSnackBar(
    context,
    '«${_titleOf(note)}» بایگانی شد',
    () => provider.setArchived(note, false),
  );
}

/// اجرای یک عمل روی یادداشت (مشترک بین لیست، شبکه و داشبورد).
Future<void> runNoteAction(
  BuildContext context,
  Note note,
  NoteAction action,
) async {
  final provider = context.read<NotesProvider>();
  switch (action) {
    case NoteAction.edit:
      await openNoteEditor(context, note: note);
    case NoteAction.pin:
      await provider.togglePin(note);
    case NoteAction.archive:
      if (note.isArchived) {
        await provider.setArchived(note, false);
      } else {
        await archiveNoteWithUndo(context, note);
      }
    case NoteAction.share:
      await Share.share(provider.shareText(note), subject: note.title);
    case NoteAction.copy:
      final messenger = ScaffoldMessenger.of(context);
      await Clipboard.setData(ClipboardData(text: provider.shareText(note)));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('متن یادداشت کپی شد'),
            showCloseIcon: true,
          ),
        );
    case NoteAction.duplicate:
      final messenger = ScaffoldMessenger.of(context);
      await provider.duplicateNote(note);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('کپی «${_titleOf(note)}» ساخته شد'),
            showCloseIcon: true,
          ),
        );
    case NoteAction.delete:
      await trashNoteWithUndo(context, note);
  }
}

/// برگه گزینه‌های یادداشت (با لمس طولانی): رنگ و همه عمل‌ها.
Future<void> showNoteActionsSheet(BuildContext context, Note note) async {
  final provider = context.read<NotesProvider>();
  final action = await showModalBottomSheet<NoteAction>(
    context: context,
    // ارتفاع طبیعی (نه سقف پیش‌فرض ۹/۱۶ صفحه) تا همه گزینه‌ها بدون اسکرول دیده شوند.
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final error = Theme.of(ctx).colorScheme.error;
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SheetColorPicker(note: note, provider: provider),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('ویرایش'),
                onTap: () => Navigator.of(ctx).pop(NoteAction.edit),
              ),
              if (!note.isArchived)
                ListTile(
                  leading: Icon(
                    note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  ),
                  title: Text(note.isPinned ? 'لغو سنجاق' : 'سنجاق کردن'),
                  onTap: () => Navigator.of(ctx).pop(NoteAction.pin),
                ),
              ListTile(
                leading: Icon(
                  note.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(note.isArchived ? 'خروج از بایگانی' : 'بایگانی'),
                onTap: () => Navigator.of(ctx).pop(NoteAction.archive),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('اشتراک‌گذاری'),
                onTap: () => Navigator.of(ctx).pop(NoteAction.share),
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('کپی متن'),
                onTap: () => Navigator.of(ctx).pop(NoteAction.copy),
              ),
              ListTile(
                leading: const Icon(Icons.control_point_duplicate_outlined),
                title: const Text('ساخت کپی از یادداشت'),
                onTap: () => Navigator.of(ctx).pop(NoteAction.duplicate),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: error),
                title: Text('حذف', style: TextStyle(color: error)),
                onTap: () => Navigator.of(ctx).pop(NoteAction.delete),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (action != null && context.mounted) {
    await runNoteAction(context, note, action);
  }
}

/// انتخاب رنگ داخل برگه؛ رنگ بلافاصله ذخیره می‌شود.
class _SheetColorPicker extends StatefulWidget {
  const _SheetColorPicker({required this.note, required this.provider});

  final Note note;
  final NotesProvider provider;

  @override
  State<_SheetColorPicker> createState() => _SheetColorPickerState();
}

class _SheetColorPickerState extends State<_SheetColorPicker> {
  late int? _color = widget.note.colorValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('رنگ یادداشت', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        PaletteColorPicker(
          selected: _color,
          allowNone: true,
          onChanged: (value) {
            setState(() => _color = value);
            widget.provider.setColor(widget.note, value);
          },
        ),
      ],
    );
  }
}
