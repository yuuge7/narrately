import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_stats.dart';
import 'database_provider.dart';

class StatsState {
  final UserStats? stats;
  final bool isLoading;

  const StatsState({
    this.stats,
    this.isLoading = true,
  });

  StatsState copyWith({
    UserStats? stats,
    bool? isLoading,
  }) {
    return StatsState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class StatsNotifier extends Notifier<StatsState> {
  @override
  StatsState build() {
    _init();
    return const StatsState();
  }

  Future<void> _init() async {
    final db = ref.read(databaseServiceProvider);
    await db.init();
    var stats = await db.getUserStats();

    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    if (stats.lastListenedDate != todayStr) {
      final lastDate = DateTime.parse(stats.lastListenedDate);
      final today = DateTime.parse(todayStr);
      final difference = today.difference(lastDate).inDays;

      int newStreak = stats.currentStreak;
      // If they missed yesterday (difference > 1), streak resets.
      if (difference > 1) {
        newStreak = 0;
      }

      stats = stats.copyWith(
        currentStreak: newStreak,
        lastListenedDate: todayStr,
        secondsListenedToday: 0,
        goalReachedToday: false,
      );
      await db.updateUserStats(stats);
    }

    state = state.copyWith(stats: stats, isLoading: false);
  }

  Future<void> addListenTime(int seconds) async {
    if (state.stats == null) return;
    
    var stats = state.stats!;
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    
    // Check rollover while listening
    if (stats.lastListenedDate != todayStr) {
      // Just re-init to handle rollover safely
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
    
    state = state.copyWith(stats: updatedStats);
    
    // Save to DB
    final db = ref.read(databaseServiceProvider);
    await db.updateUserStats(updatedStats);
  }
  
  void updateStats(UserStats newStats) {
    state = state.copyWith(stats: newStats);
  }
}

final statsProvider = NotifierProvider<StatsNotifier, StatsState>(() {
  return StatsNotifier();
});
