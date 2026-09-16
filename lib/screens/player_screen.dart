import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../providers/player_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/epub_providers.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  
  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final chapter = playerState.currentChapter;

    ref.listen(statsProvider, (previous, next) {
      if (previous?.stats?.goalReachedToday == false &&
          next.stats?.goalReachedToday == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Congratulations! You reached your daily listening goal!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
    
    ref.listen<PlayerState>(playerProvider, (previous, next) {
      if (previous?.currentChunkIndex != next.currentChunkIndex &&
          next.currentChunks.isNotEmpty &&
          next.currentChunkIndex < next.currentChunks.length) {
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: next.currentChunkIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(chapter?.title ?? 'Now Playing'),
        leading: IconButton(
          icon: const Icon(Icons.expand_more),
          tooltip: 'Minimize',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.timer, 
              color: playerState.sleepTimerEndTime != null ? Colors.orange : null,
            ),
            tooltip: 'Sleep Timer',
            onPressed: () => _showSleepTimerDialog(context, notifier, playerState),
          ),
          IconButton(
            icon: const Icon(Icons.settings_voice),
            tooltip: 'Voice Settings',
            onPressed: () => _showSettingsSheet(context, ref, playerState, notifier),
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.format_list_bulleted),
              tooltip: 'Chapters',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _buildChapterDrawer(context, ref, playerState),
      body: chapter == null
          ? const Center(child: Text('No chapter selected'))
          : Column(
              children: [
                if (playerState.sleepTimerEndTime != null)
                  _SleepTimerCountdown(endTime: playerState.sleepTimerEndTime!),
                  
                Expanded(
                  child: playerState.currentChunks.isEmpty
                      ? const Center(child: Text('Empty chapter'))
                      : ScrollablePositionedList.builder(
                          itemCount: playerState.currentChunks.length,
                          itemBuilder: (context, index) {
                            final isActive = index == playerState.currentChunkIndex;
                            return Container(
                              color: isActive 
                                ? Theme.of(context).colorScheme.primaryContainer.withAlpha(100) 
                                : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              child: Text(
                                playerState.currentChunks[index],
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  height: 1.6,
                                  color: isActive 
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurface.withAlpha(150),
                                  fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                        ),
                ),
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                  padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                  child: Column(
                    children: [
                      if (playerState.currentChunks.isNotEmpty)
                        LinearProgressIndicator(
                          value: playerState.currentChunkIndex / playerState.currentChunks.length,
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            iconSize: 36,
                            onPressed: () => notifier.skipToPreviousChapter(),
                            tooltip: 'Previous Chapter',
                          ),
                          IconButton(
                            icon: const Icon(Icons.replay_10),
                            iconSize: 42,
                            onPressed: () => notifier.rewind(),
                            tooltip: 'Rewind',
                          ),
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
                          IconButton(
                            icon: const Icon(Icons.forward_10),
                            iconSize: 42,
                            onPressed: () => notifier.fastForward(),
                            tooltip: 'Fast Forward',
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            iconSize: 36,
                            onPressed: () => notifier.skipToNextChapter(),
                            tooltip: 'Next Chapter',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildChapterDrawer(BuildContext context, WidgetRef ref, PlayerState state) {
    if (state.currentChapter == null) return const Drawer();
    
    final libraryState = ref.read(libraryProvider);
    final book = libraryState.books.firstWhere(
      (b) => b.id == state.currentChapter!.bookId,
      orElse: () => throw Exception('Book not found'),
    );
    
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Text(
                book.title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: book.chapters.length,
              itemBuilder: (context, index) {
                final c = book.chapters[index];
                final isCurrent = c.id == state.currentChapter!.id;
                
                return ListTile(
                  title: Text(
                    c.title,
                    style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                  ),
                  selected: isCurrent,
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(playerProvider.notifier).playChapter(c);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  void _showSleepTimerDialog(BuildContext context, PlayerNotifier notifier, PlayerState state) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Sleep Timer', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                title: const Text('Off'),
                trailing: state.sleepTimerEndTime == null ? const Icon(Icons.check) : null,
                onTap: () {
                  notifier.setSleepTimer(0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('15 Minutes'),
                onTap: () {
                  notifier.setSleepTimer(15);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('30 Minutes'),
                onTap: () {
                  notifier.setSleepTimer(30);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('60 Minutes'),
                onTap: () {
                  notifier.setSleepTimer(60);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref, PlayerState state, PlayerNotifier notifier) async {
    final tts = ref.read(ttsServiceProvider);
    final voices = await tts.getVoices();
    
    if (!context.mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _VoiceSettingsSheet(
          voices: voices,
          state: state,
          notifier: notifier,
        );
      }
    );
  }
}

class _VoiceSettingsSheet extends StatefulWidget {
  final List<Map<String, String>> voices;
  final PlayerState state;
  final PlayerNotifier notifier;

  const _VoiceSettingsSheet({
    required this.voices,
    required this.state,
    required this.notifier,
  });

  @override
  State<_VoiceSettingsSheet> createState() => _VoiceSettingsSheetState();
}

class _VoiceSettingsSheetState extends State<_VoiceSettingsSheet> {
  late double _speed;
  late double _pitch;
  String? _selectedVoiceIdentifier;

  @override
  void initState() {
    super.initState();
    _speed = widget.state.playbackSpeed;
    _pitch = widget.state.playbackPitch;
    if (widget.state.voiceName != null) {
      _selectedVoiceIdentifier = '${widget.state.voiceName}|${widget.state.voiceLocale}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Voice Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          
          Text('Speed: ${_speed.toStringAsFixed(2)}x'),
          Slider(
            value: _speed,
            min: 0.5,
            max: 2.0,
            divisions: 6,
            onChanged: (val) {
              setState(() => _speed = val);
            },
            onChangeEnd: (val) => widget.notifier.setSpeed(val),
          ),
          
          Text('Pitch: ${_pitch.toStringAsFixed(2)}'),
          Slider(
            value: _pitch,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            onChanged: (val) {
              setState(() => _pitch = val);
            },
            onChangeEnd: (val) => widget.notifier.setPitch(val),
          ),
          
          const SizedBox(height: 16),
          const Text('Select Voice:'),
          if (widget.voices.isEmpty)
            const Text('No voices available on this device.')
          else
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedVoiceIdentifier,
              hint: const Text('Default System Voice'),
              items: widget.voices.map((v) {
                final id = '${v['name']}|${v['locale']}';
                return DropdownMenuItem(
                  value: id,
                  child: Text('${v['name']} (${v['locale']})'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedVoiceIdentifier = val);
                  final parts = val.split('|');
                  widget.notifier.setVoice({'name': parts[0], 'locale': parts[1]});
                }
              },
            ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SleepTimerCountdown extends StatefulWidget {
  final DateTime endTime;
  const _SleepTimerCountdown({required this.endTime});

  @override
  State<_SleepTimerCountdown> createState() => _SleepTimerCountdownState();
}

class _SleepTimerCountdownState extends State<_SleepTimerCountdown> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) => _updateRemaining());
  }
  
  @override
  void didUpdateWidget(covariant _SleepTimerCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTime != widget.endTime) {
      _updateRemaining();
    }
  }

  void _updateRemaining() {
    final now = DateTime.now();
    setState(() {
      _remaining = widget.endTime.difference(now);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) return const SizedBox.shrink();
    
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    
    return Container(
      width: double.infinity,
      color: Colors.orange.withAlpha(50),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Text(
          'Sleep in $minutes:$seconds',
          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
