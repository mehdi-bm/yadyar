import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../providers/notes_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import 'widgets/note_actions.dart';
import 'widgets/note_card.dart';

enum NotesCollection { archived, trash }

/// «بایگانی» یا «حذف‌شده‌ها»ی یادداشت‌ها.
class NotesCollectionScreen extends StatelessWidget {
  const NotesCollectionScreen({super.key, required this.collection});

  final NotesCollection collection;

  bool get _isTrash => collection == NotesCollection.trash;

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), showCloseIcon: true));
  }

  Future<void> _restore(BuildContext context, Note note) async {
    final provider = context.read<NotesProvider>();
    if (_isTrash) {
      await provider.restoreFromTrash(note);
    } else {
      await provider.setArchived(note, false);
    }
    if (context.mounted) {
      _toast(context, '«${note.title}» به یادداشت‌ها برگشت');
    }
  }

  Future<void> _deleteForever(BuildContext context, Note note) async {
    final confirmed = await showDeleteNoteConfirmation(context);
    if (confirmed && context.mounted) {
      await context.read<NotesProvider>().deleteNote(note.id!);
    }
  }

  Future<void> _emptyTrash(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'خالی کردن حذف‌شده‌ها',
      message:
          'همه یادداشت‌های این بخش برای همیشه حذف می‌شوند و دیگر قابل بازیابی نیستند.',
      confirmLabel: 'خالی کن',
    );
    if (confirmed && context.mounted) {
      await context.read<NotesProvider>().emptyTrash();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotesProvider>();
    final notes = _isTrash ? provider.trashedNotes : provider.archivedNotes;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isTrash ? 'یادداشت‌های حذف‌شده' : 'بایگانی یادداشت‌ها'),
        actions: [
          if (_isTrash && notes.isNotEmpty)
            TextButton.icon(
              onPressed: () => _emptyTrash(context),
              icon: Icon(
                Icons.delete_forever_outlined,
                color: theme.colorScheme.error,
              ),
              label: Text(
                'خالی کردن',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
      body: notes.isEmpty
          ? EmptyStateView(
              icon: _isTrash
                  ? Icons.restore_from_trash_outlined
                  : Icons.archive_outlined,
              message: _isTrash
                  ? 'بخش حذف‌شده‌ها خالی است.\nیادداشت‌های حذف‌شده تا ${formatNumber(NotesProvider.trashRetention.inDays)} روز اینجا نگه داشته می‌شوند.'
                  : 'بایگانی خالی است.\nیادداشت‌هایی که فعلاً لازم ندارید را بایگانی کنید تا لیست اصلی خلوت بماند.',
            )
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                if (_isTrash)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'یادداشت‌های حذف‌شده پس از ${formatNumber(NotesProvider.trashRetention.inDays)} روز خودکار برای همیشه پاک می‌شوند.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final note in notes)
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    color: noteTintColor(context, note),
                    child: ListTile(
                      contentPadding: const EdgeInsetsDirectional.only(
                        start: 16,
                        end: 4,
                      ),
                      title: Text(
                        note.title.isEmpty ? '(بدون عنوان)' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        [
                          if (note.content.isNotEmpty)
                            note.content.replaceAll('\n', ' '),
                          _isTrash
                              ? 'حذف: ${formatJalaliDate(note.deletedAt!)}'
                              : 'آخرین ویرایش: ${formatJalaliDate(note.updatedAt)}',
                        ].join('\n'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: _isTrash
                          ? null
                          : () => openNoteEditor(context, note: note),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isTrash
                                  ? Icons.restore
                                  : Icons.unarchive_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            tooltip: _isTrash ? 'بازگردانی' : 'خروج از بایگانی',
                            onPressed: () => _restore(context, note),
                          ),
                          IconButton(
                            icon: Icon(
                              _isTrash
                                  ? Icons.delete_forever_outlined
                                  : Icons.delete_outline,
                              color: theme.colorScheme.error,
                            ),
                            tooltip: _isTrash ? 'حذف برای همیشه' : 'حذف',
                            onPressed: () => _isTrash
                                ? _deleteForever(context, note)
                                : trashNoteWithUndo(context, note),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
