import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'stats_provider.dart';

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
    // StatsNotifier owns the user_stats row; writing it from here with a
    // cached copy would revert whatever the player had saved since. build()
    // watches statsProvider, so its update is what re-derives the ThemeMode.
    await ref.read(statsProvider.notifier).setThemeMode(mode);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});
