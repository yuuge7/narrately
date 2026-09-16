import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../models/chapter.dart';
import '../services/tts_service.dart';
import '../services/audio_handler.dart';
import 'database_provider.dart';
import 'epub_providers.dart';
import 'stats_provider.dart';

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
}

class PlayerNotifier extends Notifier<PlayerState> {
  late TtsService _ttsService;
  bool _isStoppingForSeek = false;
  Timer? _listenTimer;
  Timer? _sleepTimer;

  @override
  PlayerState build() {
    _ttsService = ref.watch(ttsServiceProvider);
    
    _ttsService.setCompletionHandler(() {
      _onChunkFinished();
    });
    
    _ttsService.setCancelHandler(() {
      if (!_isStoppingForSeek) {
        _stopTimer();
        state = state.copyWith(isPlaying: false);
        _updateAudioServiceState(false);
      }
    });

    // Wire up audioHandler callbacks
    audioHandler?.onPlay = resume;
    audioHandler?.onPause = pause;
    audioHandler?.onStop = pause;
    audioHandler?.onFastForward = fastForward;
    audioHandler?.onRewind = rewind;
    audioHandler?.onSkipToNext = skipToNextChapter;
    audioHandler?.onSkipToPrevious = skipToPreviousChapter;

    ref.onDispose(() {
      _stopTimer();
      _cancelSleepTimer();
    });
    
    _loadInitialSettings();

    return const PlayerState();
  }
  
  Future<void> _loadInitialSettings() async {
    // We delay slightly to allow stats provider to load, or we fetch direct from db
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
      if (state.isPlaying) {
        ref.read(statsProvider.notifier).addListenTime(1);
      }
    });
  }

  void _stopTimer() {
    _listenTimer?.cancel();
    _listenTimer = null;
  }
  
  void setSleepTimer(int minutes) {
    _cancelSleepTimer();
    if (minutes > 0) {
      final endTime = DateTime.now().add(Duration(minutes: minutes));
      state = state.copyWith(sleepTimerEndTime: endTime);
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        pause();
        state = state.copyWith(sleepTimerEndTime: null);
      });
    } else {
      state = state.copyWith(sleepTimerEndTime: null);
    }
  }
  
  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  void _updateAudioServiceState(bool playing) {
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
    
    if (state.currentChapter != null) {
      final libraryState = ref.read(libraryProvider);
      final bookTitle = libraryState.books
          .where((b) => b.id == state.currentChapter!.bookId)
          .firstOrNull?.title ?? 'Unknown Book';
          
      audioHandler?.mediaItem.add(MediaItem(
        id: state.currentChapter!.id,
        title: state.currentChapter!.title,
        artist: bookTitle,
      ));
    }
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
    
    if (state.currentChunkIndex + 1 < state.currentChunks.length) {
      state = state.copyWith(currentChunkIndex: state.currentChunkIndex + 1);
      await _ttsService.speak(state.currentChunks[state.currentChunkIndex]);
    } else {
      await _onChapterFinished();
    }
  }

  Future<void> _onChapterFinished() async {
    final chapter = state.currentChapter;
    if (chapter == null) {
      _stopTimer();
      state = state.copyWith(isPlaying: false);
      _updateAudioServiceState(false);
      return;
    }
    
    final libraryState = ref.read(libraryProvider);
    final book = libraryState.books.firstWhere(
      (b) => b.id == chapter.bookId,
      orElse: () => throw Exception('Book not found'),
    );
    
    final currentIndex = chapter.index;
    if (currentIndex + 1 < book.chapters.length) {
      final nextChapter = book.chapters[currentIndex + 1];
      await playChapter(nextChapter);
    } else {
      _stopTimer();
      state = state.copyWith(isPlaying: false);
      _updateAudioServiceState(false);
    }
  }
  
  Future<void> skipToNextChapter() async {
    final chapter = state.currentChapter;
    if (chapter == null) return;
    final libraryState = ref.read(libraryProvider);
    final book = libraryState.books.firstWhere((b) => b.id == chapter.bookId);
    
    if (chapter.index + 1 < book.chapters.length) {
      await playChapter(book.chapters[chapter.index + 1]);
    }
  }

  Future<void> skipToPreviousChapter() async {
    final chapter = state.currentChapter;
    if (chapter == null) return;
    final libraryState = ref.read(libraryProvider);
    final book = libraryState.books.firstWhere((b) => b.id == chapter.bookId);
    
    if (chapter.index - 1 >= 0) {
      await playChapter(book.chapters[chapter.index - 1]);
    }
  }

  Future<void> playChapter(Chapter chapter) async {
    if (state.currentChapter?.id != chapter.id && state.isPlaying) {
      _isStoppingForSeek = true;
      await _ttsService.stop();
      _isStoppingForSeek = false;
    }
    
    final chunks = _chunkText(chapter.textContent);
    
    state = state.copyWith(
      currentChapter: chapter,
      isPlaying: true,
      currentChunks: chunks,
      currentChunkIndex: 0,
    );
    
    _startTimer();
    _updateAudioServiceState(true);
    
    final db = ref.read(databaseServiceProvider);
    await db.savePlaybackState(chapter.bookId, chapter.id);
    
    if (chunks.isNotEmpty) {
      await _ttsService.speak(chunks[0]);
    } else {
      await _onChapterFinished();
    }
  }

  Future<void> setSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    await _ttsService.setSpeechRate(speed);
    
    final db = ref.read(databaseServiceProvider);
    var stats = await db.getUserStats();
    await db.updateUserStats(stats.copyWith(preferredSpeed: speed));
    
    if (state.isPlaying && state.currentChunks.isNotEmpty) {
      _isStoppingForSeek = true;
      await _ttsService.stop();
      _isStoppingForSeek = false;
      await _ttsService.speak(state.currentChunks[state.currentChunkIndex]);
    }
  }
  
  Future<void> setPitch(double pitch) async {
    state = state.copyWith(playbackPitch: pitch);
    await _ttsService.setPitch(pitch);
    
    final db = ref.read(databaseServiceProvider);
    var stats = await db.getUserStats();
    await db.updateUserStats(stats.copyWith(preferredPitch: pitch));
    
    if (state.isPlaying && state.currentChunks.isNotEmpty) {
      _isStoppingForSeek = true;
      await _ttsService.stop();
      _isStoppingForSeek = false;
      await _ttsService.speak(state.currentChunks[state.currentChunkIndex]);
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
      _isStoppingForSeek = true;
      await _ttsService.stop();
      _isStoppingForSeek = false;
      await _ttsService.speak(state.currentChunks[state.currentChunkIndex]);
    }
  }

  Future<void> pause() async {
    _isStoppingForSeek = true;
    await _ttsService.stop();
    _isStoppingForSeek = false;
    _stopTimer();
    state = state.copyWith(isPlaying: false);
    _updateAudioServiceState(false);
  }

  Future<void> resume() async {
    if (state.currentChunks.isNotEmpty && state.currentChunkIndex < state.currentChunks.length) {
      state = state.copyWith(isPlaying: true);
      _startTimer();
      _updateAudioServiceState(true);
      await _ttsService.speak(state.currentChunks[state.currentChunkIndex]);
    }
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
    _isStoppingForSeek = true;
    await _ttsService.stop();
    _isStoppingForSeek = false;
    
    state = state.copyWith(currentChunkIndex: newIndex);
    if (state.isPlaying) {
      await _ttsService.speak(state.currentChunks[newIndex]);
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
