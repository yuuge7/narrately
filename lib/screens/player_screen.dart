import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final chapter = playerState.currentChapter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        leading: IconButton(
          icon: const Icon(Icons.expand_more),
          tooltip: 'Minimize',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<double>(
            initialValue: playerState.playbackSpeed,
            tooltip: 'Playback Speed',
            icon: Row(
              children: [
                Text(
                  '${playerState.playbackSpeed}x',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.speed),
              ],
            ),
            onSelected: (speed) => notifier.setSpeed(speed),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0.75, child: Text('0.75x')),
              const PopupMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
              const PopupMenuItem(value: 1.25, child: Text('1.25x')),
              const PopupMenuItem(value: 1.5, child: Text('1.5x')),
              const PopupMenuItem(value: 2.0, child: Text('2.0x')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: chapter == null
          ? const Center(child: Text('No chapter selected'))
          : Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.headset, size: 80, color: Colors.deepPurple),
                  const SizedBox(height: 32),
                  Text(
                    chapter.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 64),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        iconSize: 48,
                        onPressed: () => notifier.rewind(),
                        tooltip: 'Rewind',
                      ),
                      const SizedBox(width: 24),
                      FloatingActionButton.large(
                        onPressed: () {
                          if (playerState.isPlaying) {
                            notifier.pause();
                          } else {
                            notifier.resume();
                          }
                        },
                        child: Icon(
                          playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 48,
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.forward_10),
                        iconSize: 48,
                        onPressed: () => notifier.fastForward(),
                        tooltip: 'Fast Forward',
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (playerState.currentChunks.isNotEmpty)
                    LinearProgressIndicator(
                      value: playerState.currentChunkIndex / playerState.currentChunks.length,
                    ),
                ],
              ),
            ),
    );
  }
}
