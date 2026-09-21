import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/backup_provider.dart';
import '../../providers/bills_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/shopping_provider.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BackupProvider>().loadBackups();
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _createBackup(BackupProvider provider) async {
    try {
      await provider.createBackup();
      if (mounted) _showMessage('نسخه پشتیبان با موفقیت ساخته شد.');
    } on Object catch (e) {
      if (mounted) _showMessage('خطا در تهیه نسخه پشتیبان: $e', isError: true);
    }
  }

  Future<void> _shareBackup(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'نسخه پشتیبان یادیار',
      text: 'نسخه پشتیبان اطلاعات یادیار — ${_backupLabel(file)}',
    );
  }

  Future<void> _restore(BackupProvider provider, File file) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'بازیابی نسخه پشتیبان',
      message:
          'با این کار همه اطلاعات فعلی اپ (یادداشت‌ها، قبض‌ها، لیست‌های خرید) '
          'با محتوای این فایل جایگزین می‌شود. پیش از این کار، یک نسخه پشتیبان '
          'ایمنی از وضعیت فعلی به‌صورت خودکار ساخته می‌شود. ادامه می‌دهید؟',
      confirmLabel: 'بازیابی',
    );
    if (!confirmed || !mounted) return;

    try {
      await provider.restoreFromFile(file);
      if (!mounted) return;
      // بازخوانی همه Providerهای زنده اپ تا داده‌های جدید بلافاصله نمایش داده شوند.
      final notesProvider = context.read<NotesProvider>();
      final billsProvider = context.read<BillsProvider>();
      final shoppingProvider = context.read<ShoppingProvider>();
      await notesProvider.loadNotes();
      await billsProvider.loadSubscriptions();
      await shoppingProvider.loadLists();
      if (mounted) _showMessage('بازیابی با موفقیت انجام شد.');
    } on FormatException catch (e) {
      if (mounted) _showMessage(e.message, isError: true);
    } on Object catch (e) {
      if (mounted) _showMessage('خطا در بازیابی: $e', isError: true);
    }
  }

  Future<void> _restoreFromExternalFile(BackupProvider provider) async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    await _restore(provider, File(path));
  }

  Future<void> _deleteBackup(BackupProvider provider, File file) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف نسخه پشتیبان',
      message: 'این فایل پشتیبان برای همیشه حذف می‌شود. آیا مطمئن هستید؟',
    );
    if (!confirmed) return;
    await provider.deleteBackup(file);
  }

  String _backupLabel(File file) {
    final match = RegExp(r'(\d{8})_(\d{6})').firstMatch(p.basename(file.path));
    if (match == null) return p.basename(file.path);
    final datePart = match.group(1)!;
    final timePart = match.group(2)!;
    final dateTime = DateTime(
      int.parse(datePart.substring(0, 4)),
      int.parse(datePart.substring(4, 6)),
      int.parse(datePart.substring(6, 8)),
      int.parse(timePart.substring(0, 2)),
      int.parse(timePart.substring(2, 4)),
      int.parse(timePart.substring(4, 6)),
    );
    return formatJalaliDateTime(dateTime);
  }

  bool _isSafetyBackup(File file) =>
      p.basename(file.path).contains('pre-restore');

  String _formatSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes بایت';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} کیلوبایت';
    return '${(kb / 1024).toStringAsFixed(1)} مگابایت';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BackupProvider>();
    final backups = provider.backups;

    return Scaffold(
      appBar: AppBar(title: const Text('پشتیبان‌گیری و بازیابی')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: provider.isBusy
                        ? null
                        : () => _createBackup(provider),
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('تهیه نسخه پشتیبان جدید'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: provider.isBusy
                        ? null
                        : () => _restoreFromExternalFile(provider),
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('بازیابی از فایل دیگر...'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : backups.isEmpty
                ? const EmptyStateView(
                    icon: Icons.backup_outlined,
                    message:
                        'هنوز نسخه پشتیبانی ساخته نشده است.\nبرای شروع، دکمه بالا را بزنید.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: backups.length,
                    itemBuilder: (context, index) {
                      final file = backups[index];
                      final isSafety = _isSafetyBackup(file);
                      return ListTile(
                        leading: Icon(
                          isSafety
                              ? Icons.shield_outlined
                              : Icons.description_outlined,
                        ),
                        title: Text(_backupLabel(file)),
                        subtitle: Text(
                          isSafety
                              ? 'نسخه ایمنی خودکار (پیش از آخرین بازیابی) — ${_formatSize(file)}'
                              : _formatSize(file),
                        ),
                        trailing: PopupMenuButton<String>(
                          enabled: !provider.isBusy,
                          onSelected: (action) {
                            switch (action) {
                              case 'restore':
                                _restore(provider, file);
                              case 'share':
                                _shareBackup(file);
                              case 'delete':
                                _deleteBackup(provider, file);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'restore',
                              child: Text('بازیابی این نسخه'),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Text('اشتراک‌گذاری / ذخیره در جای دیگر'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'حذف',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
