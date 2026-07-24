import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/note.dart';
import '../../providers/notes_provider.dart';
import 'note_edit_screen.dart';
import 'widgets/note_actions.dart';
import 'widgets/note_card.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotesProvider>().loadNotes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor(BuildContext context, {Note? note}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => NoteEditScreen(note: note)),
    );
  }

  Future<void> _handleLongPress(BuildContext context, Note note) async {
    final provider = context.read<NotesProvider>();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('ویرایش'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(note.isPinned ? 'لغو سنجاق' : 'سنجاق کردن'),
              onTap: () => Navigator.of(ctx).pop('pin'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
              title: Text('حذف', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _openEditor(context, note: note);
      case 'pin':
        await provider.togglePin(note);
      case 'delete':
        final confirmed = await showDeleteNoteConfirmation(context);
        if (confirmed) await provider.deleteNote(note.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotesProvider>();
    final notes = provider.filteredNotes;
    final tags = provider.allTags;
    final isFiltering = provider.searchQuery.isNotEmpty || provider.selectedTag != null;

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'جستجو در یادداشت‌ها...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          provider.setSearchQuery('');
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: provider.setSearchQuery,
            ),
          ),
          if (tags.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: tags.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  return FilterChip(
                    label: Text(tag),
                    selected: provider.selectedTag == tag,
                    onSelected: (_) => provider.setTagFilter(tag),
                  );
                },
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : notes.isEmpty
                ? _EmptyState(isFiltering: isFiltering)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return NoteCard(
                        note: note,
                        onTap: () => _openEditor(context, note: note),
                        onLongPress: () => _handleLongPress(context, note),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        tooltip: 'یادداشت جدید',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isFiltering});

  final bool isFiltering;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_alt_outlined, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              isFiltering
                  ? 'یادداشتی با این مشخصات پیدا نشد.'
                  : 'هنوز یادداشتی ثبت نشده است.\nبرای شروع، دکمه + را بزنید.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
