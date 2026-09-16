import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'stats_provider.dart';
import 'database_provider.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final statsState = ref.watch(statsProvider);
    if (statsState.stats == null) return ThemeMode.system;
    
    switch (statsState.stats!.themeMode) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(String mode) async {
    final statsState = ref.read(statsProvider);
    if (statsState.stats == null) return;
    
    final updatedStats = statsState.stats!.copyWith(themeMode: mode);
    final db = ref.read(databaseServiceProvider);
    await db.updateUserStats(updatedStats);
    
    // We update stats provider to trigger the rebuild
    // Actually wait, statsProvider updates its own state, but we don't have a method to just update it there.
    // Let's just force a re-init or use a local state.
    // In StatsProvider we should probably just have a method to update stats.
    ref.read(statsProvider.notifier).updateStats(updatedStats);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});
