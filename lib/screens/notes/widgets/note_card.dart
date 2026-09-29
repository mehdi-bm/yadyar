import 'package:flutter/material.dart';

import '../../../models/note.dart';
import '../../../models/reminder.dart';
import '../../../utils/date_formatter.dart';

/// رنگ پس‌زمینه کارت یادداشت: ترکیب ملایم رنگ یادداشت با سطح کارت تا در
/// هر دو تم روشن و تیره خوانا بماند.
Color? noteTintColor(BuildContext context, Note note) {
  final value = note.colorValue;
  if (value == null) return null;
  final surface =
      Theme.of(context).cardTheme.color ??
      Theme.of(context).colorScheme.surfaceContainerLow;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Color.alphaBlend(
    Color(value).withValues(alpha: isDark ? 0.28 : 0.22),
    surface,
  );
}

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,
    this.reminder,
    this.nextReminder,
    this.compact = false,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// یادآور این یادداشت، در صورت وجود.
  final Reminder? reminder;

  /// زمان رخداد بعدی یادآور (برای یادآور تکرارشونده با [Reminder.dateTime]
  /// فرق دارد)؛ null یعنی یادآور فعالی در پیش نیست.
  final DateTime? nextReminder;

  /// حالت فشرده برای نمای شبکه‌ای.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = noteTintColor(context, note);
    final accent = note.colorValue != null
        ? Color(note.colorValue!)
        : scheme.primary;
    final upcoming = nextReminder;

    return Card(
      margin: compact
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: tint,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!compact) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.sticky_note_2_outlined,
                        size: 20,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: compact ? 0 : 8),
                      child: Text(
                        note.title.isEmpty ? '(بدون عنوان)' : note.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (note.isPinned)
                    Padding(
                      padding: EdgeInsets.only(top: compact ? 0 : 8),
                      child: Icon(Icons.push_pin, size: 18, color: accent),
                    ),
                ],
              ),
              if (note.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: compact ? 6 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (upcoming != null) ...[
                const SizedBox(height: 8),
                _ReminderChip(
                  when: upcoming,
                  isRepeating:
                      reminder != null &&
                      reminder!.repeatType != ReminderRepeatType.none,
                  compact: compact,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (note.tag.isNotEmpty)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '#${note.tag}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (!compact || note.tag.isEmpty)
                    Text(
                      formatJalaliDate(note.updatedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderChip extends StatelessWidget {
  const _ReminderChip({
    required this.when,
    required this.isRepeating,
    required this.compact,
  });

  final DateTime when;
  final bool isRepeating;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRepeating ? Icons.repeat : Icons.notifications_active_outlined,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              compact
                  ? relativeFutureLabel(when)
                  : '${formatJalaliDateTime(when)} • ${relativeFutureLabel(when)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
