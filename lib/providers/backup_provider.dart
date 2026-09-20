import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/book_parse_exception.dart';
import 'database_provider.dart';
import 'epub_providers.dart';
import 'library_progress_provider.dart';
import 'player_provider.dart';
import 'recent_playback_provider.dart';
import 'stats_provider.dart';

class BackupState {
  final bool isBusy;
  final String? message;
  final bool isError;

  const BackupState({this.isBusy = false, this.message, this.isError = false});
}

/// Saving the library to a file and putting it back.
///
/// The backup is the sqflite database itself: books, chapter text, positions,
/// bookmarks, streaks and settings, all in one file. Cover images live beside
/// it in the app's own storage and are not included, so a backup restored onto
/// a fresh install shows placeholder covers — the text, which is what gets
/// read aloud, is all in the database.
class BackupNotifier extends Notifier<BackupState> {
  @override
  BackupState build() => const BackupState();

  Future<void> exportBackup() async {
    state = const BackupState(isBusy: true);

    try {
      final db = ref.read(databaseServiceProvider);
      final bytes = await db.exportBytes();

      final today = DateTime.now().toIso8601String().split('T')[0];
      final saved = await ref
          .read(filePickerServiceProvider)
          .saveBackup('narrately-backup-$today.db', bytes);

      if (saved == null) {
        state = const BackupState();
        return;
      }

      final size = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      state = BackupState(message: 'Backup saved ($size MB).');
    } catch (e) {
      state = BackupState(message: describeError(e), isError: true);
    }
  }

  /// Replaces the library with a backup. The caller confirms first: this
  /// throws away everything currently in the app.
  Future<void> restoreBackup() async {
    state = const BackupState(isBusy: true);

    try {
      final path = await ref.read(filePickerServiceProvider).pickBackupFile();
      if (path == null) {
        state = const BackupState();
        return;
      }

      final db = ref.read(databaseServiceProvider);
      if (!await db.looksLikeBackup(path)) {
        state = const BackupState(
          message: 'That file is not a Narrately backup.',
          isError: true,
        );
        return;
      }

      // Stop playback before the database under it is swapped out.
      await ref.read(playerProvider.notifier).pause();
      await db.restoreFrom(path);

      // Everything in memory belongs to the database that was just replaced.
      ref.invalidate(playerProvider);
      ref.invalidate(recentPlaybackProvider);
      ref.invalidate(libraryProgressProvider);
      await ref.read(libraryProvider.notifier).reload();
      await ref.read(statsProvider.notifier).reload();

      state = const BackupState(message: 'Backup restored.');
    } catch (e) {
      state = BackupState(message: describeError(e), isError: true);
    }
  }

  void clearMessage() {
    if (state.message != null) state = BackupState(isBusy: state.isBusy);
  }
}

final backupProvider = NotifierProvider<BackupNotifier, BackupState>(() {
  return BackupNotifier();
});
