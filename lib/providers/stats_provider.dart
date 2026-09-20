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
    
    var stats = state.stats!;
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    
    if (stats.lastListenedDate != todayStr) {
      await _init();
      stats = state.stats!;
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
    
    final db = ref.read(databaseServiceProvider);
    await db.updateUserStats(updatedStats);
    await db.saveListeningHistory(todayStr, newSeconds, goalReachedToday);
    
    final newHistory = Map<String, bool>.from(state.history);
    newHistory[todayStr] = goalReachedToday;
    
    state = state.copyWith(stats: updatedStats, history: newHistory);
  }
  
  Future<void> setDailyGoal(int seconds) async {
    if (state.stats == null) return;
    final updatedStats = state.stats!.copyWith(dailyGoalSeconds: seconds);
    await ref.read(databaseServiceProvider).updateUserStats(updatedStats);
    state = state.copyWith(stats: updatedStats);
  }

  void updateStats(UserStats newStats) {
    state = state.copyWith(stats: newStats);
  }

  Future<void> setFontSize(double size) async {
    if (state.stats == null) return;
    final updatedStats = state.stats!.copyWith(preferredFontSize: size);
    await ref.read(databaseServiceProvider).updateUserStats(updatedStats);
    state = state.copyWith(stats: updatedStats);
  }
}

final statsProvider = NotifierProvider<StatsNotifier, StatsState>(() {
  return StatsNotifier();
});
