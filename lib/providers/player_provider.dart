import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chapter.dart';
import '../services/tts_service.dart';

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

class PlayerState {
  final Chapter? currentChapter;
  final bool isPlaying;

  const PlayerState({
    this.currentChapter,
    this.isPlaying = false,
  });

  PlayerState copyWith({
    Chapter? currentChapter,
    bool? isPlaying,
  }) {
    return PlayerState(
      currentChapter: currentChapter ?? this.currentChapter,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

class PlayerNotifier extends Notifier<PlayerState> {
  late TtsService _ttsService;

  @override
  PlayerState build() {
    _ttsService = ref.watch(ttsServiceProvider);
    
    _ttsService.setCompletionHandler(() {
      state = state.copyWith(isPlaying: false);
    });
    
    _ttsService.setCancelHandler(() {
      state = state.copyWith(isPlaying: false);
    });

    return const PlayerState();
  }

  Future<void> playChapter(Chapter chapter) async {
    // If playing a different chapter, stop current
    if (state.currentChapter?.id != chapter.id && state.isPlaying) {
      await _ttsService.stop();
    }
    
    state = state.copyWith(
      currentChapter: chapter,
      isPlaying: true,
    );
    
    await _ttsService.speak(chapter.textContent);
  }

  Future<void> resume() async {
    if (state.currentChapter != null && !state.isPlaying) {
      state = state.copyWith(isPlaying: true);
      // For now (Slice 2), resume just speaks the chapter from the beginning
      // since we aren't saving position yet.
      await _ttsService.speak(state.currentChapter!.textContent);
    }
  }

  Future<void> pause() async {
    if (state.isPlaying) {
      state = state.copyWith(isPlaying: false);
      await _ttsService.pause();
    }
  }

  Future<void> stop() async {
    state = state.copyWith(isPlaying: false);
    await _ttsService.stop();
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(() {
  return PlayerNotifier();
});
