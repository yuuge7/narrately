import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../services/tts_service.dart';
import '../services/audio_handler.dart';
import 'database_provider.dart';
import 'epub_providers.dart';
import 'stats_provider.dart';
import 'recent_playback_provider.dart';

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

class PlayerState {
  final Chapter? currentChapter;
  final bool isPlaying;
  final double playbackSpeed;
  final double playbackPitch;
  final String? voiceName;
  final String? voiceLocale;
  final List<String> currentChunks;
  final int currentChunkIndex;
  final DateTime? sleepTimerEndTime;

  const PlayerState({
    this.currentChapter,
    this.isPlaying = false,
    this.playbackSpeed = 1.0,
    this.playbackPitch = 1.0,
    this.voiceName,
    this.voiceLocale,
    this.currentChunks = const [],
    this.currentChunkIndex = 0,
    this.sleepTimerEndTime,
  });

  PlayerState copyWith({
    Chapter? currentChapter,
    bool? isPlaying,
    double? playbackSpeed,
    double? playbackPitch,
    String? voiceName,
    String? voiceLocale,
    List<String>? currentChunks,
    int? currentChunkIndex,
    DateTime? sleepTimerEndTime,
  }) {
    return PlayerState(
      currentChapter: currentChapter ?? this.currentChapter,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      playbackPitch: playbackPitch ?? this.playbackPitch,
      voiceName: voiceName ?? this.voiceName,
      voiceLocale: voiceLocale ?? this.voiceLocale,
      currentChunks: currentChunks ?? this.currentChunks,
      currentChunkIndex: currentChunkIndex ?? this.currentChunkIndex,
      sleepTimerEndTime: sleepTimerEndTime ?? this.sleepTimerEndTime,
    );
  }

  /// copyWith cannot set a nullable field back to null, so clearing the sleep
  /// timer needs its own constructor call.
  PlayerState withoutSleepTimer() {
    return PlayerState(
      currentChapter: currentChapter,
      isPlaying: isPlaying,
      playbackSpeed: playbackSpeed,
      playbackPitch: playbackPitch,
      voiceName: voiceName,
      voiceLocale: voiceLocale,
      currentChunks: currentChunks,
      currentChunkIndex: currentChunkIndex,
      sleepTimerEndTime: null,
    );
  }
}

class PlayerNotifier extends Notifier<PlayerState> {
  static const int _flushIntervalSeconds = 5;

  late TtsService _ttsService;
  bool _isStoppingForSeek = false;
  Timer? _listenTimer;
  int _unflushedSeconds = 0;
  Timer? _sleepTimer;

  @override
  PlayerState build() {
    _ttsService = ref.watch(ttsServiceProvider);

    _ttsService.setCompletionHandler(() {
      _onChunkFinished();
    });

    // Only a real synthesis error means playback stopped. The cancel callback
    // also fires every time a new utterance flushes the previous one, so using
    // it here left isPlaying false while the engine kept reading aloud.
    _ttsService.setErrorHandler((message) {
      _stopTimer();
      state = state.copyWith(isPlaying: false);
      _updateAudioServiceState(false);
    });

    audioHandler?.onPlay = resume;
    audioHandler?.onPause = pause;
    audioHandler?.onStop = pause;
    audioHandler?.onFastForward = fastForward;
    audioHandler?.onRewind = rewind;
    audioHandler?.onSkipToNext = skipToNextChapter;
    audioHandler?.onSkipToPrevious = skipToPreviousChapter;

    ref.onDispose(() {
      _listenTimer?.cancel();
      _listenTimer = null;
      _cancelSleepTimer();
    });

    _loadInitialSettings();

    return const PlayerState();
  }

  Future<void> _loadInitialSettings() async {
    final db = ref.read(databaseServiceProvider);
    final stats = await db.getUserStats();

    state = state.copyWith(
      playbackSpeed: stats.preferredSpeed,
      playbackPitch: stats.preferredPitch,
      voiceName: stats.preferredVoiceName,
      voiceLocale: stats.preferredVoiceLocale,
    );

    await _ttsService.setSpeechRate(stats.preferredSpeed);
    await _ttsService.setPitch(stats.preferredPitch);
    if (stats.preferredVoiceName != null && stats.preferredVoiceLocale != null) {
      await _ttsService.setVoice({
        'name': stats.preferredVoiceName!,
        'locale': stats.preferredVoiceLocale!,
      });
    }
  }

  void _startTimer() {
    _stopTimer();
    _listenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isPlaying) return;
      _unflushedSeconds++;
      if (_unflushedSeconds >= _flushIntervalSeconds) {
        _flushListenTime();
      }
    });
  }

  void _stopTimer() {
    _listenTimer?.cancel();
    _listenTimer = null;
    _flushListenTime();
  }

  /// Listening time is written in [_flushIntervalSeconds] batches; a write per
  /// tick meant two DB round trips every second for the whole playback session.
  void _flushListenTime() {
    if (_unflushedSeconds <= 0) return;
    final seconds = _unflushedSeconds;
    _unflushedSeconds = 0;
    ref.read(statsProvider.notifier).addListenTime(seconds);
  }

  void setSleepTimer(int minutes) {
    _cancelSleepTimer();
    if (minutes > 0) {
      final endTime = DateTime.now().add(Duration(minutes: minutes));
      state = state.copyWith(sleepTimerEndTime: endTime);
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        pause();
        state = state.withoutSleepTimer();
      });
    } else {
      state = state.withoutSleepTimer();
    }
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  /// The book may have been deleted while it was still playing, so every
  /// lookup has to tolerate a miss rather than throwing into an async gap.
  Book? _bookFor(Chapter chapter) {
    for (final book in ref.read(libraryProvider).books) {
      if (book.id == chapter.bookId) return book;
    }
    return null;
  }

  void _updateAudioServiceState(bool playing) {
    if (state.currentChapter != null) {
      final bookTitle = _bookFor(state.currentChapter!)?.title ?? 'Unknown Book';

      audioHandler?.mediaItem.add(MediaItem(
        id: state.currentChapter!.id,
        title: state.currentChapter!.title,
        artist: bookTitle,
        duration: const Duration(hours: 10), // Dummy duration for persistent notification
      ));
    }

    audioHandler?.playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.rewind,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [1, 2, 3],
      processingState: AudioProcessingState.ready,
      playing: playing,
    ));
  }

  /// Starts an utterance at a new position. The engine is always flushed
  /// first: speaking over a live utterance makes Android cancel the old one,
  /// and the completion of that cancelled utterance would otherwise advance
  /// the chunk index a second time.
  Future<void> _speakFrom(String text) async {
    _isStoppingForSeek = true;
    await _ttsService.stop();
    _isStoppingForSeek = false;
    await _ttsService.speak(text);
  }

  List<String> _chunkText(String text) {
    final chunks = <String>[];
    final regex = RegExp(r'[^.!?]+[.!?]+(?:\s+|$)');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      if (text.trim().isNotEmpty) {
        chunks.add(text.trim());
      }
      return chunks;
    }

    for (final match in matches) {
      final chunk = match.group(0)?.trim();
      if (chunk != null && chunk.isNotEmpty) {
        chunks.add(chunk);
      }
    }

    final lastMatchEnd = matches.last.end;
    if (lastMatchEnd < text.length) {
      final remainder = text.substring(lastMatchEnd).trim();
      if (remainder.isNotEmpty) {
        chunks.add(remainder);
      }
    }

    return chunks;
  }

  Future<void> _onChunkFinished() async {
    if (_isStoppingForSeek) return;
    if (!state.isPlaying) return;

    if (state.currentChunkIndex + 1 < state.currentChunks.length) {
      state = state.copyWith(currentChunkIndex: state.currentChunkIndex + 1);

      if (state.currentChapter != null) {
        ref.read(databaseServiceProvider).savePlaybackState(
          state.currentChapter!.bookId,
          state.currentChapter!.id,
          state.currentChunkIndex
        );
        ref.invalidate(recentPlaybackProvider);
      }

      // The previous utterance ended on its own, so no flush is needed here.
      await _ttsService.speak(state.currentChunks[state.currentChunkIndex]);
    } else {
      await _onChapterFinished();
    }
  }

  Future<void> _onChapterFinished() async {
    final chapter = state.currentChapter;
    final book = chapter == null ? null : _bookFor(chapter);
    if (chapter == null || book == null) {
      _stopTimer();
      state = state.copyWith(isPlaying: false);
      _updateAudioServiceState(false);
      return;
    }

    final currentIndex = chapter.index;
    if (currentIndex + 1 < book.chapters.length) {
      final nextChapter = book.chapters[currentIndex + 1];
      await playChapter(nextChapter, forceRestart: true);
    } else {
      _stopTimer();
      state = state.copyWith(isPlaying: false);
      _updateAudioServiceState(false);
    }
  }

  Future<void> skipToNextChapter() async {
    final chapter = state.currentChapter;
    if (chapter == null) return;
    final book = _bookFor(chapter);
    if (book == null) return;

    if (chapter.index + 1 < book.chapters.length) {
      await playChapter(book.chapters[chapter.index + 1], forceRestart: true);
    }
  }

  Future<void> skipToPreviousChapter() async {
    final chapter = state.currentChapter;
    if (chapter == null) return;
    final book = _bookFor(chapter);
    if (book == null) return;

    if (chapter.index - 1 >= 0) {
      await playChapter(book.chapters[chapter.index - 1], forceRestart: true);
    }
  }

  Future<void> playChapter(Chapter chapter, {int startingChunkIndex = 0, bool forceRestart = false, bool autoPlay = true}) async {
    if (!forceRestart && state.currentChapter?.id == chapter.id) {
      if (!state.isPlaying && autoPlay) {
        await resume();
      }
      return;
    }

    final chunks = _chunkText(chapter.textContent);

    if (startingChunkIndex >= chunks.length || startingChunkIndex < 0) {
      startingChunkIndex = 0;
    }

    state = state.copyWith(
      currentChapter: chapter,
      isPlaying: autoPlay,
      currentChunks: chunks,
      currentChunkIndex: startingChunkIndex,
    );

    if (autoPlay) {
      _startTimer();
    } else {
      _stopTimer();
    }
    _updateAudioServiceState(autoPlay);

    final db = ref.read(databaseServiceProvider);
    await db.savePlaybackState(chapter.bookId, chapter.id, startingChunkIndex);
    ref.invalidate(recentPlaybackProvider);

    if (autoPlay) {
      if (chunks.isNotEmpty) {
        await _speakFrom(chunks[startingChunkIndex]);
      } else {
        await _onChapterFinished();
      }
    } else {
      // Opening a chapter without playing must not leave the engine reading
      // whatever was queued before.
      _isStoppingForSeek = true;
      await _ttsService.stop();
      _isStoppingForSeek = false;
    }
  }

  Future<void> setSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    await _ttsService.setSpeechRate(speed);

    final db = ref.read(databaseServiceProvider);
    var stats = await db.getUserStats();
    await db.updateUserStats(stats.copyWith(preferredSpeed: speed));

    if (state.isPlaying && state.currentChunks.isNotEmpty) {
      await _speakFrom(state.currentChunks[state.currentChunkIndex]);
    }
  }

  Future<void> setPitch(double pitch) async {
    state = state.copyWith(playbackPitch: pitch);
    await _ttsService.setPitch(pitch);

    final db = ref.read(databaseServiceProvider);
    var stats = await db.getUserStats();
    await db.updateUserStats(stats.copyWith(preferredPitch: pitch));

    if (state.isPlaying && state.currentChunks.isNotEmpty) {
      await _speakFrom(state.currentChunks[state.currentChunkIndex]);
    }
  }

  Future<void> setVoice(Map<String, String> voice) async {
    state = state.copyWith(voiceName: voice['name'], voiceLocale: voice['locale']);
    await _ttsService.setVoice(voice);

    final db = ref.read(databaseServiceProvider);
    var stats = await db.getUserStats();
    await db.updateUserStats(stats.copyWith(
      preferredVoiceName: voice['name'],
      preferredVoiceLocale: voice['locale'],
    ));

    if (state.isPlaying && state.currentChunks.isNotEmpty) {
      await _speakFrom(state.currentChunks[state.currentChunkIndex]);
    }
  }

  Future<void> pause() async {
    _isStoppingForSeek = true;
    await _ttsService.stop();
    _isStoppingForSeek = false;
    _stopTimer();
    state = state.copyWith(isPlaying: false);
    _updateAudioServiceState(false);

    if (state.currentChapter != null) {
      final db = ref.read(databaseServiceProvider);
      await db.savePlaybackState(
        state.currentChapter!.bookId,
        state.currentChapter!.id,
        state.currentChunkIndex
      );
      ref.invalidate(recentPlaybackProvider);
    }
  }

  Future<void> resume() async {
    var chunks = state.currentChunks;
    if (chunks.isEmpty) {
      final chapter = state.currentChapter;
      if (chapter == null) return;
      chunks = _chunkText(chapter.textContent);
      if (chunks.isEmpty) return;
      state = state.copyWith(currentChunks: chunks, currentChunkIndex: 0);
    }

    final index = state.currentChunkIndex.clamp(0, chunks.length - 1);
    state = state.copyWith(isPlaying: true, currentChunkIndex: index);
    _startTimer();
    _updateAudioServiceState(true);
    await _speakFrom(chunks[index]);
  }

  Future<void> fastForward() async {
    if (state.currentChunks.isEmpty) return;

    int targetIndex = state.currentChunkIndex;
    int wordsSkipped = 0;
    while (wordsSkipped < 50 && targetIndex < state.currentChunks.length - 1) {
      wordsSkipped += _countWords(state.currentChunks[targetIndex]);
      targetIndex++;
    }

    await _seekToChunk(targetIndex);
  }

  Future<void> rewind() async {
    if (state.currentChunks.isEmpty) return;

    int targetIndex = state.currentChunkIndex;
    int wordsSkipped = 0;
    while (wordsSkipped < 50 && targetIndex > 0) {
      targetIndex--;
      wordsSkipped += _countWords(state.currentChunks[targetIndex]);
    }

    await _seekToChunk(targetIndex);
  }

  Future<void> _seekToChunk(int newIndex) async {
    state = state.copyWith(currentChunkIndex: newIndex);

    if (state.currentChapter != null) {
      ref.read(databaseServiceProvider).savePlaybackState(
        state.currentChapter!.bookId,
        state.currentChapter!.id,
        state.currentChunkIndex
      );
      ref.invalidate(recentPlaybackProvider);
    }

    if (state.isPlaying) {
      await _speakFrom(state.currentChunks[newIndex]);
    } else {
      _isStoppingForSeek = true;
      await _ttsService.stop();
      _isStoppingForSeek = false;
    }
  }

  int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(() {
  return PlayerNotifier();
});
