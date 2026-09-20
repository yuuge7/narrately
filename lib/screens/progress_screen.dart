import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../models/chapter.dart';
import '../models/user_stats.dart';
import '../providers/epub_providers.dart';
import '../providers/player_provider.dart';
import '../providers/recent_playback_provider.dart';
import '../providers/stats_provider.dart';
import 'player_screen.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsState = ref.watch(statsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Progress')),
          if (statsState.isLoading || statsState.stats == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            SliverToBoxAdapter(
              child: _ContinueListeningCard(),
            ),
            SliverToBoxAdapter(
              child: _TodayCard(stats: statsState.stats!),
            ),
            SliverToBoxAdapter(
              child: _StreakRow(stats: statsState.stats!),
            ),
            SliverToBoxAdapter(
              child: _HistoryCard(history: statsState.history),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _SectionCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.5),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Picks up the most recent `playback_state` row so the last book is one tap
/// away from any screen.
class _ContinueListeningCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentPlaybackProvider);
    final books = ref.watch(libraryProvider).books;

    return recent.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (row) {
        if (row == null) return const SizedBox.shrink();

        final bookId = row['book_id'] as String?;
        final chapterId = row['last_chapter_id'] as String?;
        final chunkIndex = (row['last_position_words'] as int?) ?? 0;
        if (bookId == null || chapterId == null) return const SizedBox.shrink();

        Book? book;
        for (final b in books) {
          if (b.id == bookId) book = b;
        }
        if (book == null || book.chapters.isEmpty) {
          return const SizedBox.shrink();
        }

        Chapter? chapter;
        for (final c in book.chapters) {
          if (c.id == chapterId) chapter = c;
        }
        chapter ??= book.chapters.first;

        return _SectionCard(
          label: 'CONTINUE',
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.play_arrow_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              chapter.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              ref.read(playerProvider.notifier).playChapter(
                    chapter!,
                    startingChunkIndex: chunkIndex,
                    forceRestart: true,
                    autoPlay: false,
                  );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PlayerScreen(),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TodayCard extends ConsumerWidget {
  final UserStats stats;

  const _TodayCard({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = stats.dailyGoalSeconds;
    final listened = stats.secondsListenedToday;
    final progress = goal > 0 ? (listened / goal).clamp(0.0, 1.0) : 0.0;

    return _SectionCard(
      label: 'TODAY',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              height: 140,
              width: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    color: stats.goalReachedToday
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${listened ~/ 60}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'of ${goal ~/ 60} min',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              stats.goalReachedToday
                  ? 'Daily goal reached 🎉'
                  : 'Keep going to hit today\'s goal',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  final UserStats stats;

  const _StreakRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      label: 'STREAKS',
      child: Row(
        children: [
          Expanded(
            child: _StreakTile(
              icon: Icons.local_fire_department,
              color: Colors.orange,
              value: '${stats.currentStreak}',
              label: 'Current',
            ),
          ),
          Container(
            width: 1,
            height: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: _StreakTile(
              icon: Icons.emoji_events_rounded,
              color: Colors.amber,
              value: '${stats.longestStreak}',
              label: 'Longest',
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StreakTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '$label streak',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value == '1' ? '1 day' : '$value days',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// Last 30 days, newest at the bottom right, so the grid reads like a calendar.
class _HistoryCard extends StatelessWidget {
  final Map<String, bool> history;

  const _HistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(30, (i) {
      final date = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 29 - i));
      final key = date.toIso8601String().split('T').first;
      return (date: date, reached: history[key] ?? false);
    });

    return _SectionCard(
      label: 'LAST 30 DAYS',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: days.map((day) {
                return Tooltip(
                  message: day.date.toIso8601String().split('T').first,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: day.reached
                          ? Colors.green
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: Center(
                      child: Text(
                        '${day.date.day}',
                        style: TextStyle(
                          fontSize: 10,
                          color: day.reached
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              '${days.where((d) => d.reached).length} of 30 days hit the goal',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
