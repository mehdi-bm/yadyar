import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/backup_service.dart';

class BackupProvider extends ChangeNotifier {
  BackupProvider({BackupService? backupService})
    : _backupService = backupService ?? BackupService();

  final BackupService _backupService;

  List<File> _backups = [];
  bool _isLoading = true;
  bool _isBusy = false;

  List<File> get backups => List.unmodifiable(_backups);
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;

  Future<void> loadBackups() async {
    _isLoading = true;
    notifyListeners();
    _backups = await _backupService.listBackups();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createBackup() async {
    _isBusy = true;
    notifyListeners();
    try {
      await _backupService.createBackup();
      await loadBackups();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// [FormatException] در صورتی که فایل انتخاب‌شده یک نسخه پشتیبان معتبر یادیار نباشد.
  Future<void> restoreFromFile(File file) async {
    _isBusy = true;
    notifyListeners();
    try {
      await _backupService.restoreFromFile(file);
      await loadBackups();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> deleteBackup(File file) async {
    await _backupService.deleteBackup(file);
    await loadBackups();
  }
}
