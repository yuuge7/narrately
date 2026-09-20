import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_stats.dart';
import 'database_provider.dart';

class StatsState {
  final UserStats? stats;
  final bool isLoading;
  final Map<String, bool> history; // Date string -> goalReached

  const StatsState({
    this.stats,
    this.isLoading = true,
    this.history = const {},
  });

  StatsState copyWith({
    UserStats? stats,
    bool? isLoading,
    Map<String, bool>? history,
  }) {
    return StatsState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      history: history ?? this.history,
    );
  }
}

class StatsNotifier extends Notifier<StatsState> {
  @override
  StatsState build() {
    _init();
    return const StatsState();
  }

  static String _dayKey(DateTime date) =>
      DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];

  Future<void> _init() async {
    final db = ref.read(databaseServiceProvider);
    await db.init();
    var stats = await db.getUserStats();

    final now = DateTime.now();
    final todayStr = _dayKey(now);
    final yesterdayStr = _dayKey(now.subtract(const Duration(days: 1)));

    final historyData = await db.getListeningHistory(30);
    final Map<String, bool> historyMap = {};
    for (final row in historyData) {
      historyMap[row['date'] as String] = (row['goal_reached'] as int) == 1;
    }

    final reachedToday = historyMap[todayStr] ?? false;
    final reachedYesterday = historyMap[yesterdayStr] ?? false;

    // The streak survives only if the goal was met today or yesterday. Reading
    // this from listening_history instead of lastListenedDate is what makes a
    // missed day actually break the chain: lastListenedDate is bumped on every
    // launch, so a day with no listening used to look like an unbroken run.
    var updated = stats;
    if (!reachedToday && !reachedYesterday && stats.currentStreak > 0) {
      updated = updated.copyWith(currentStreak: 0);
    }

    // New day: today's counters start over.
    if (stats.lastListenedDate != todayStr) {
      updated = updated.copyWith(
        lastListenedDate: todayStr,
        secondsListenedToday: 0,
        goalReachedToday: false,
      );
    }

    if (!identical(updated, stats)) {
      await db.updateUserStats(updated);
      stats = updated;
    }

    historyMap[todayStr] = stats.goalReachedToday;

    state = state.copyWith(stats: stats, isLoading: false, history: historyMap);
  }

  Future<void> addListenTime(int seconds) async {
    if (state.stats == null) return;

    final db = ref.read(databaseServiceProvider);
    final todayStr = _dayKey(DateTime.now());

    // Re-read instead of trusting the cached copy. This runs every few seconds
    // while playing and rewrites the whole row, so using a copy loaded at
    // startup wiped anything the player had saved since — the preferred voice
    // disappeared a few seconds after being chosen.
    var stats = await db.getUserStats();

    if (stats.lastListenedDate != todayStr) {
      await _init();
      stats = await db.getUserStats();
    }

    final newSeconds = stats.secondsListenedToday + seconds;
    int newStreak = stats.currentStreak;
    int newLongest = stats.longestStreak;
    bool goalReachedToday = stats.goalReachedToday;
    
    if (!stats.goalReachedToday && newSeconds >= stats.dailyGoalSeconds) {
      goalReachedToday = true;
      newStreak += 1;
      if (newStreak > newLongest) {
        newLongest = newStreak;
      }
    }
    
    final updatedStats = stats.copyWith(
      secondsListenedToday: newSeconds,
      currentStreak: newStreak,
      longestStreak: newLongest,
      goalReachedToday: goalReachedToday,
    );
    
    await db.updateUserStats(updatedStats);
    await db.saveListeningHistory(todayStr, newSeconds, goalReachedToday);
    
    final newHistory = Map<String, bool>.from(state.history);
    newHistory[todayStr] = goalReachedToday;
    
    state = state.copyWith(stats: updatedStats, history: newHistory);
  }
  
  Future<void> setDailyGoal(int seconds) async {
    await _update((stats) => stats.copyWith(dailyGoalSeconds: seconds));
  }

  Future<void> setFontSize(double size) async {
    await _update((stats) => stats.copyWith(preferredFontSize: size));
  }

  Future<void> setThemeMode(String mode) async {
    await _update((stats) => stats.copyWith(themeMode: mode));
  }

  Future<void> setLibrarySort(String sortKey) async {
    await _update((stats) => stats.copyWith(librarySort: sortKey));
  }

  /// Re-reads everything from the database. Used after a backup is restored,
  /// where the stats in memory belong to the database that was replaced.
  Future<void> reload() async {
    state = const StatsState();
    await _init();
  }

  void updateStats(UserStats newStats) {
    state = state.copyWith(stats: newStats);
  }

  /// Applies one change to `user_stats`, re-reading the row first.
  ///
  /// `user_stats` is a single row written by this notifier and by the player,
  /// and [DatabaseService.updateUserStats] replaces the whole row. Writing a
  /// cached copy therefore silently reverted whatever the other one had saved
  /// since this notifier last loaded — changing the font size wiped the
  /// preferred voice.
  Future<void> _update(UserStats Function(UserStats current) change) async {
    final db = ref.read(databaseServiceProvider);
    final updated = change(await db.getUserStats());
    await db.updateUserStats(updated);
    state = state.copyWith(stats: updated);
  }
}

final statsProvider = NotifierProvider<StatsNotifier, StatsState>(() {
  return StatsNotifier();
});
