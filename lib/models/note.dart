class Note {
  const Note({
    this.id,
    required this.title,
    required this.content,
    required this.tag,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.colorValue,
    this.isArchived = false,
    this.deletedAt,
  });

  final int? id;
  final String title;
  final String content;
  final String tag;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// رنگ دلخواه کارت یادداشت (ARGB)؛ null یعنی بی‌رنگ.
  final int? colorValue;
  final bool isArchived;

  /// زمان انتقال به «حذف‌شده‌ها»؛ null یعنی یادداشت فعال (یا بایگانی) است.
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Note copyWith({
    int? id,
    String? title,
    String? content,
    String? tag,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? colorValue,
    bool clearColor = false,
    bool? isArchived,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tag: tag ?? this.tag,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      isArchived: isArchived ?? this.isArchived,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tag': tag,
      'isPinned': isPinned ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'colorValue': colorValue,
      'isArchived': isArchived ? 1 : 0,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, Object?> map) {
    return Note(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      tag: map['tag'] as String,
      isPinned: (map['isPinned'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      colorValue: map['colorValue'] as int?,
      isArchived: (map['isArchived'] as int? ?? 0) == 1,
      deletedAt: map['deletedAt'] == null
          ? null
          : DateTime.parse(map['deletedAt'] as String),
    );
  }
}
