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
                        icon: const Icon(Icons.stop),
                        iconSize: 48,
                        onPressed: () => notifier.stop(),
                        tooltip: 'Stop',
                      ),
                      const SizedBox(width: 32),
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
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
