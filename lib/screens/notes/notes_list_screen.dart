import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/note.dart';
import '../../providers/notes_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state.dart';
import 'notes_collection_screen.dart';
import 'widgets/note_actions.dart';
import 'widgets/note_card.dart';

enum _MoreAction { archive, trash }

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
      if (!mounted) return;
      final provider = context.read<NotesProvider>();
      provider.loadNotes();
      provider.loadPreferences();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCollection(NotesCollection collection) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NotesCollectionScreen(collection: collection),
      ),
    );
  }

  Widget _buildCard(NotesProvider provider, Note note, {bool compact = false}) {
    return NoteCard(
      key: ValueKey('note-card-${note.id}'),
      note: note,
      reminder: provider.reminderForNote(note.id!),
      nextReminder: provider.nextReminderFor(note.id),
      compact: compact,
      onTap: () => openNoteEditor(context, note: note),
      onLongPress: () => showNoteActionsSheet(context, note),
    );
  }

  /// در نمای لیستی: کشیدن به یک سو بایگانی، به سوی دیگر حذف (با بازگردانی).
  Widget _swipeable(NotesProvider provider, Note note) {
    final scheme = Theme.of(context).colorScheme;
    Widget background(IconData icon, String label, Color color, bool start) =>
        Container(
          alignment: start
              ? AlignmentDirectional.centerStart
              : AlignmentDirectional.centerEnd,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          color: color,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

    return Dismissible(
      key: ValueKey('note-${note.id}'),
      background: background(
        Icons.archive_outlined,
        'بایگانی',
        scheme.primary,
        true,
      ),
      secondaryBackground: background(
        Icons.delete_outline,
        'حذف',
        scheme.error,
        false,
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          archiveNoteWithUndo(context, note);
        } else {
          trashNoteWithUndo(context, note);
        }
      },
      child: _buildCard(provider, note),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotesProvider>();
    final notes = provider.filteredNotes;
    final tags = provider.allTags;
    final isFiltering =
        provider.searchQuery.isNotEmpty ||
        provider.selectedTag != null ||
        provider.onlyWithReminder;
    final pinned = notes.where((note) => note.isPinned).toList();
    final others = notes.where((note) => !note.isPinned).toList();
    final showSections = pinned.isNotEmpty && others.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: Icon(
              provider.isGridView
                  ? Icons.view_agenda_outlined
                  : Icons.grid_view_outlined,
            ),
            tooltip: provider.isGridView ? 'نمای لیستی' : 'نمای شبکه‌ای',
            onPressed: provider.toggleGridView,
          ),
          PopupMenuButton<NoteSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'مرتب‌سازی',
            initialValue: provider.sortOption,
            onSelected: provider.setSortOption,
            itemBuilder: (context) => NoteSortOption.values
                .map(
                  (option) => PopupMenuItem(
                    value: option,
                    child: Row(
                      children: [
                        if (option == provider.sortOption)
                          const Icon(Icons.check, size: 18)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(noteSortOptionLabels[option]!),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          PopupMenuButton<_MoreAction>(
            tooltip: 'گزینه‌های بیشتر',
            onSelected: (action) => _openCollection(
              action == _MoreAction.archive
                  ? NotesCollection.archived
                  : NotesCollection.trash,
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MoreAction.archive,
                child: Row(
                  children: [
                    const Icon(Icons.archive_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text('بایگانی (${formatNumber(provider.archivedCount)})'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _MoreAction.trash,
                child: Row(
                  children: [
                    const Icon(Icons.restore_from_trash_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text('حذف‌شده‌ها (${formatNumber(provider.trashCount)})'),
                  ],
                ),
              ),
            ],
          ),
          const ThemeModeButton(),
        ],
      ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: provider.setSearchQuery,
            ),
          ),
          if (tags.isNotEmpty || provider.withReminderCount > 0)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                children: [
                  _chip(
                    label: 'همه',
                    selected:
                        provider.selectedTag == null &&
                        !provider.onlyWithReminder,
                    onSelected: () {
                      if (provider.onlyWithReminder) {
                        provider.toggleReminderFilter();
                      }
                      provider.setTagFilter(null);
                    },
                  ),
                  if (provider.withReminderCount > 0)
                    _chip(
                      label:
                          'یادآوردار (${formatNumber(provider.withReminderCount)})',
                      icon: Icons.notifications_active_outlined,
                      selected: provider.onlyWithReminder,
                      onSelected: provider.toggleReminderFilter,
                    ),
                  for (final tag in tags)
                    _chip(
                      label: '#$tag',
                      selected: provider.selectedTag == tag,
                      onSelected: () => provider.setTagFilter(tag),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: provider.isLoading && notes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : notes.isEmpty
                ? EmptyStateView(
                    icon: Icons.note_alt_outlined,
                    message: isFiltering
                        ? 'یادداشتی با این مشخصات پیدا نشد.'
                        : 'هنوز یادداشتی ثبت نشده است.\nبرای شروع، دکمه + را بزنید.',
                    actionLabel: isFiltering ? null : 'افزودن اولین یادداشت',
                    onAction: isFiltering
                        ? null
                        : () => openNoteEditor(context),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 88),
                    children: [
                      if (showSections)
                        const _SectionTitle(
                          icon: Icons.push_pin_outlined,
                          title: 'سنجاق‌شده',
                        ),
                      ..._notesBlock(provider, showSections ? pinned : notes),
                      if (showSections) ...[
                        const _SectionTitle(
                          icon: Icons.notes_outlined,
                          title: 'سایر یادداشت‌ها',
                        ),
                        ..._notesBlock(provider, others),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openNoteEditor(context),
        tooltip: 'یادداشت جدید',
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Widget> _notesBlock(NotesProvider provider, List<Note> notes) {
    if (!provider.isGridView) {
      return [for (final note in notes) _swipeable(provider, note)];
    }
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 700 ? 3 : 2;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < columns; column++)
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = column; i < notes.length; i += columns)
                          _buildCard(provider, notes[i], compact: true),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ];
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: FilterChip(
        avatar: icon == null ? null : Icon(icon, size: 16),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
