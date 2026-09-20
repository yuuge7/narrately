import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../services/tts_service.dart';
import '../services/text_chunker.dart';
import '../services/voice_matcher.dart';
import '../services/audio_handler.dart';
import 'database_provider.dart';
import 'epub_providers.dart';
import 'library_progress_provider.dart';
import 'stats_provider.dart';
import 'recent_playback_provider.dart';

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

/// The word the engine is speaking right now.
///
/// This lives apart from [PlayerState] on purpose: it changes several times a
/// second, and putting it in the player state rebuilt the whole chunk list —
/// and with it the scroll machinery — on every word.
class SpokenWord {
  final int chunkIndex;
  final int start;
  final int end;

  const SpokenWord({
    required this.chunkIndex,
    required this.start,
    required this.end,
  });
}

class SpokenWordNotifier extends Notifier<SpokenWord?> {
  @override
  SpokenWord? build() => null;

  void show(SpokenWord word) => state = word;

  void clear() {
    if (state != null) state = null;
  }
}

final spokenWordProvider = NotifierProvider<SpokenWordNotifier, SpokenWord?>(() {
  return SpokenWordNotifier();
});

class PlayerState {
  final Chapter? currentChapter;
  final bool isPlaying;
  final double playbackSpeed;
  final double playbackPitch;
  final String? voiceName;
  final String? voiceLocale;
  final List<TextChunk> currentChunks;
  final int currentChunkIndex;
  final DateTime? sleepTimerEndTime;

  /// Stop when the current chapter ends instead of rolling into the next one.
  final bool stopAtChapterEnd;

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
    this.stopAtChapterEnd = false,
  });

  PlayerState copyWith({
    Chapter? currentChapter,
    bool? isPlaying,
    double? playbackSpeed,
    double? playbackPitch,
    String? voiceName,
    String? voiceLocale,
    List<TextChunk>? currentChunks,
    int? currentChunkIndex,
    DateTime? sleepTimerEndTime,
    bool? stopAtChapterEnd,
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
      stopAtChapterEnd: stopAtChapterEnd ?? this.stopAtChapterEnd,
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
      stopAtChapterEnd: false,
    );
  }

  /// True while any kind of sleep timer is armed.
  bool get hasSleepTimer => sleepTimerEndTime != null || stopAtChapterEnd;
}

class PlayerNotifier extends Notifier<PlayerState> {
  static const int _flushIntervalSeconds = 5;

  /// Words a minute at speed 1.0, used only to give the lock screen a sensible
  /// progress bar. Nothing in the app depends on it being exact: the engine
  /// reports no duration, so any figure here is an estimate.
  static const double _wordsPerMinute = 155;

  late TtsService _ttsService;
  bool _isStoppingForSeek = false;
  bool _disposed = false;
  Timer? _listenTimer;
  int _unflushedSeconds = 0;
  Timer? _sleepTimer;

  AudioSession? _audioSession;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;
  bool _pausedByInterruption = false;

  /// Voice chosen for each language during this session, keyed by primary
  /// subtag. Seeded from the saved preference and updated whenever the user
  /// picks a voice by hand, so an automatic switch never discards their choice.
  final Map<String, Map<String, String>> _voiceByLanguage = {};

  /// The voice saved in user_stats, used for books whose language is unknown.
  Map<String, String>? _preferredVoice;

  /// The speed saved in user_stats, used for books with no override of their
  /// own and as the starting point for the next book.
  double _defaultSpeed = 1.0;

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
      _clearSpokenWord();
      _updateAudioServiceState(false);
    });

    _ttsService.setProgressHandler((text, start, end, word) {
      if (_disposed || !state.isPlaying) return;
      ref.read(spokenWordProvider.notifier).show(SpokenWord(
            chunkIndex: state.currentChunkIndex,
            start: start,
            end: end,
          ));
    });

    audioHandler?.onPlay = resume;
    audioHandler?.onPause = pause;
    audioHandler?.onStop = pause;
    audioHandler?.onFastForward = fastForward;
    audioHandler?.onRewind = rewind;
    audioHandler?.onSkipToNext = skipToNextChapter;
    audioHandler?.onSkipToPrevious = skipToPreviousChapter;
    audioHandler?.onSeek = seekToPosition;

    ref.onDispose(() {
      _disposed = true;
      _listenTimer?.cancel();
      _listenTimer = null;
      _cancelSleepTimer();
      _interruptionSub?.cancel();
      _noisySub?.cancel();
    });

    _loadInitialSettings();
    _listenForAudioInterruptions();

    return const PlayerState();
  }

  Future<void> _loadInitialSettings() async {
    final db = ref.read(databaseServiceProvider);
    final stats = await db.getUserStats();
    if (_disposed) return;

    _defaultSpeed = stats.preferredSpeed;

    state = state.copyWith(
      playbackSpeed: stats.preferredSpeed,
      playbackPitch: stats.preferredPitch,
      voiceName: stats.preferredVoiceName,
      voiceLocale: stats.preferredVoiceLocale,
    );

    await _ttsService.setSpeechRate(stats.preferredSpeed);
    await _ttsService.setPitch(stats.preferredPitch);
    if (stats.preferredVoiceName != null && stats.preferredVoiceLocale != null) {
      final saved = {
        'name': stats.preferredVoiceName!,
        'locale': stats.preferredVoiceLocale!,
      };
      await _ttsService.setVoice(saved);
      _preferredVoice = saved;

      final code = primaryLanguageCode(stats.preferredVoiceLocale);
      if (code != null) _voiceByLanguage[code] = saved;
    }
  }

  // ---------------------------------------------------------------- audio focus

  /// Reacts to another app taking the audio: a call, a navigation prompt, a
  /// music player. Without this the narration carried on underneath.
  Future<void> _listenForAudioInterruptions() async {
    try {
      final session = await AudioSession.instance;
      if (_disposed) return;

      _audioSession = session;
      _interruptionSub =
          session.interruptionEventStream.listen(_onInterruption);
      _noisySub = session.becomingNoisyEventStream.listen((_) {
        // Headphones pulled out. Continuing would play the book out loud.
        if (state.isPlaying) pause();
      });
    } catch (e) {
      // Audio focus is a courtesy; playback must still work without it.
    }
  }

  void _onInterruption(AudioInterruptionEvent event) {
    if (event.begin) {
      // The session is configured with androidWillPauseWhenDucked, so a duck
      // request arrives as a pause and speech is never left half-audible.
      if (event.type == AudioInterruptionType.duck) return;
      if (!state.isPlaying) return;
      _pausedByInterruption = true;
      // Keep the focus request alive. Abandoning it here unregisters the
      // listener that reports the focus coming back, so the call would end
      // and the book would stay silent.
      pause(releaseFocus: false);
      return;
    }

    if (!_pausedByInterruption) return;
    _pausedByInterruption = false;

    // Only a transient interruption hands the audio back. After a permanent
    // one another app is playing, and resuming would talk over it.
    if (event.type == AudioInterruptionType.pause) resume();
  }

  Future<void> _setSessionActive(bool active) async {
    try {
      await _audioSession?.setActive(active);
    } catch (e) {
      // Ignored for the same reason as above.
    }
  }

  // ------------------------------------------------------------------- timers

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
    if (_disposed) return;
    ref.read(statsProvider.notifier).addListenTime(seconds);
  }

  void setSleepTimer(int minutes) {
    _cancelSleepTimer();
    if (minutes > 0) {
      final endTime = DateTime.now().add(Duration(minutes: minutes));
      state = state.copyWith(
        sleepTimerEndTime: endTime,
        stopAtChapterEnd: false,
      );
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        pause();
        state = state.withoutSleepTimer();
      });
    } else {
      state = state.withoutSleepTimer();
    }
  }

  /// Keeps reading to the end of this chapter and stops there. A clock-based
  /// timer cuts off mid-sentence, which is the one thing a bedtime timer
  /// should not do to a story.
  void sleepAtChapterEnd() {
    _cancelSleepTimer();
    state = state.withoutSleepTimer().copyWith(stopAtChapterEnd: true);
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  // ------------------------------------------------------------------ helpers

  /// The book may have been deleted while it was still playing, so every
  /// lookup has to tolerate a miss rather than throwing into an async gap.
  Book? _bookFor(Chapter chapter) {
    for (final book in ref.read(libraryProvider).books) {
      if (book.id == chapter.bookId) return book;
    }
    return null;
  }

  /// Character offset of the chunk being spoken, within the chapter text.
  int get _currentOffset {
    final chunks = state.currentChunks;
    if (chunks.isEmpty) return 0;
    final index = state.currentChunkIndex.clamp(0, chunks.length - 1);
    return chunks[index].start;
  }

  void _clearSpokenWord() {
    if (_disposed) return;
    ref.read(spokenWordProvider.notifier).clear();
  }

  /// Writes the position both ways: the chunk index for a quick resume and the
  /// character offset, which survives a change to the chunking rules.
  Future<void> _savePosition({int? charOffset}) async {
    final chapter = state.currentChapter;
    if (chapter == null || _disposed) return;

    await ref.read(databaseServiceProvider).savePlaybackState(
          chapter.bookId,
          chapter.id,
          state.currentChunkIndex,
          charOffset ?? _currentOffset,
        );
    if (_disposed) return;
    ref.invalidate(recentPlaybackProvider);
  }

  /// Refreshes the progress shown on the library cards. Called at chapter
  /// boundaries rather than per sentence: it re-queries every book, and the
  /// library grid stays alive behind the player.
  void _refreshLibraryProgress() {
    if (_disposed) return;
    ref.invalidate(libraryProgressProvider);
  }

  // ------------------------------------------------------- lock screen timing

  Duration _durationForWords(int words) {
    final wordsPerSecond = _wordsPerMinute * state.playbackSpeed / 60;
    if (wordsPerSecond <= 0 || words <= 0) return Duration.zero;
    return Duration(milliseconds: (words / wordsPerSecond * 1000).round());
  }

  Duration get _chapterDuration =>
      _durationForWords(state.currentChapter?.wordCount ?? 0);

  Duration get _positionInChapter {
    final chapter = state.currentChapter;
    if (chapter == null || chapter.textContent.isEmpty) return Duration.zero;

    final total = _chapterDuration.inMilliseconds;
    if (total <= 0) return Duration.zero;

    final fraction =
        (_currentOffset / chapter.textContent.length).clamp(0.0, 1.0);
    return Duration(milliseconds: (total * fraction).round());
  }

  void _updateAudioServiceState(bool playing) {
    final chapter = state.currentChapter;
    if (chapter != null) {
      final bookTitle = _bookFor(chapter)?.title ?? 'Unknown Book';

      audioHandler?.mediaItem.add(MediaItem(
        id: chapter.id,
        title: chapter.title,
        artist: bookTitle,
        // An estimate from the word count. The old placeholder of ten hours
        // made the notification's progress bar permanently read 0%.
        duration: _chapterDuration,
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
      updatePosition: _positionInChapter,
      bufferedPosition: _chapterDuration,
      // The duration above is already expressed at the current speed, so one
      // second of real time is one second of it.
      speed: playing ? 1.0 : 0.0,
    ));
  }

  /// Handles a drag on the notification's progress bar.
  Future<void> seekToPosition(Duration position) async {
    final chapter = state.currentChapter;
    if (chapter == null || chapter.textContent.isEmpty) return;
    if (state.currentChunks.isEmpty) return;

    final total = _chapterDuration.inMilliseconds;
    if (total <= 0) return;

    final fraction = (position.inMilliseconds / total).clamp(0.0, 1.0);
    final offset = (fraction * chapter.textContent.length).round();
    await _seekToChunk(chunkIndexForOffset(state.currentChunks, offset));
  }

  // ----------------------------------------------------------------- playback

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

  Future<void> _onChunkFinished() async {
    if (_isStoppingForSeek) return;
    if (!state.isPlaying) return;

    if (state.currentChunkIndex + 1 < state.currentChunks.length) {
      state = state.copyWith(currentChunkIndex: state.currentChunkIndex + 1);
      _clearSpokenWord();

      unawaited(_savePosition());

      // The previous utterance ended on its own, so no flush is needed here.
      await _ttsService.speak(state.currentChunks[state.currentChunkIndex].text);
    } else {
      await _onChapterFinished();
    }
  }

  Future<void> _onChapterFinished() async {
    final chapter = state.currentChapter;
    final book = chapter == null ? null : _bookFor(chapter);

    // Anchor the saved position at the very end of the text, so a finished
    // book reads as finished rather than stopping a sentence short.
    if (chapter != null) {
      await _savePosition(charOffset: chapter.textContent.length);
    }
    _refreshLibraryProgress();

    if (chapter == null || book == null) {
      await _stopPlayback();
      return;
    }

    if (state.stopAtChapterEnd) {
      state = state.copyWith(stopAtChapterEnd: false);
      await _stopPlayback();
      return;
    }

    final currentIndex = chapter.index;
    if (currentIndex + 1 < book.chapters.length) {
      final nextChapter = book.chapters[currentIndex + 1];
      await playChapter(nextChapter, forceRestart: true);
    } else {
      await _stopPlayback();
    }
  }

  Future<void> _stopPlayback() async {
    _stopTimer();
    state = state.copyWith(isPlaying: false);
    _clearSpokenWord();
    _updateAudioServiceState(false);
    await _setSessionActive(false);
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

  Future<void> playChapter(
    Chapter chapter, {
    int startingChunkIndex = 0,
    int? startingCharOffset,
    bool forceRestart = false,
    bool autoPlay = true,
  }) async {
    if (!forceRestart &&
        state.currentChapter?.id == chapter.id &&
        startingCharOffset == null) {
      if (!state.isPlaying && autoPlay) {
        await resume();
      }
      return;
    }

    await _applyVoiceForBookOf(chapter);
    await _applySpeedForBookOf(chapter);

    final chunks = chunkWithOffsets(chapter.textContent);

    // A stored character offset wins over a stored index: the index is only
    // meaningful for the exact chunking that produced it.
    if (startingCharOffset != null) {
      startingChunkIndex = chunkIndexForOffset(chunks, startingCharOffset);
    } else if (startingChunkIndex >= chunks.length || startingChunkIndex < 0) {
      startingChunkIndex = 0;
    }

    state = state.copyWith(
      currentChapter: chapter,
      isPlaying: autoPlay,
      currentChunks: chunks,
      currentChunkIndex: startingChunkIndex,
    );
    _clearSpokenWord();

    if (autoPlay) {
      _startTimer();
      await _setSessionActive(true);
    } else {
      _stopTimer();
    }
    _updateAudioServiceState(autoPlay);

    await _savePosition();
    _refreshLibraryProgress();

    if (autoPlay) {
      if (chunks.isNotEmpty) {
        await _speakFrom(chunks[startingChunkIndex].text);
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

  /// Jumps to a character offset inside the chapter already loaded, or opens
  /// [chapter] there. Used by search results and bookmarks.
  Future<void> jumpTo(Chapter chapter, int charOffset, {bool play = false}) async {
    if (state.currentChapter?.id != chapter.id) {
      await playChapter(
        chapter,
        startingCharOffset: charOffset,
        forceRestart: true,
        autoPlay: play,
      );
      return;
    }

    await _seekToChunk(chunkIndexForOffset(state.currentChunks, charOffset));
    if (play && !state.isPlaying) await resume();
  }

  /// Switches to a voice matching the book's own language, so a Romanian book
  /// is not narrated by the English voice left over from the previous one.
  ///
  /// The choice is applied to the engine only, never written to user_stats:
  /// the saved preference stays the user's manual fallback.
  Future<void> _applyVoiceForBookOf(Chapter chapter) async {
    final language = _bookFor(chapter)?.language;
    final code = primaryLanguageCode(language);

    if (code == null) {
      // Books imported before the language column carry none. Fall back to the
      // saved preference rather than leaving them with a voice auto-selected
      // for some other book's language.
      final preferred = _preferredVoice;
      if (preferred != null && preferred['locale'] != state.voiceLocale) {
        await _useVoice(preferred);
      }
      return;
    }

    // Already narrating in that language, so leave the current voice alone.
    if (primaryLanguageCode(state.voiceLocale) == code) return;

    final remembered = _voiceByLanguage[code];
    if (remembered != null) {
      await _useVoice(remembered);
      return;
    }

    try {
      final match = pickVoiceForLanguage(
        await _ttsService.getVoices(),
        code,
        preferredLocale: language,
      );
      // Nothing installed for this language: keep the current voice rather
      // than leaving the engine with nothing to speak with.
      if (match == null) return;

      _voiceByLanguage[code] = match;
      await _useVoice(match);
    } catch (e) {
      // Voice listing is best-effort; playback matters more.
    }
  }

  /// Applies this book's own speed, falling back to the global default. A
  /// dense non-fiction book and a novel rarely want the same pace.
  Future<void> _applySpeedForBookOf(Chapter chapter) async {
    final speed = _bookFor(chapter)?.playbackSpeed ?? _defaultSpeed;
    if (speed == state.playbackSpeed) return;

    state = state.copyWith(playbackSpeed: speed);
    await _ttsService.setSpeechRate(speed);
  }

  Future<void> _useVoice(Map<String, String> voice) async {
    await _ttsService.setVoice(voice);
    state = state.copyWith(
      voiceName: voice['name'],
      voiceLocale: voice['locale'],
    );
  }

  /// Sets the narration speed for the book being read, and makes it the
  /// starting point for books that have no speed of their own yet.
  Future<void> setSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    await _ttsService.setSpeechRate(speed);

    _defaultSpeed = speed;
    final db = ref.read(databaseServiceProvider);
    final stats = await db.getUserStats();
    await db.updateUserStats(stats.copyWith(preferredSpeed: speed));

    final chapter = state.currentChapter;
    if (chapter != null) {
      await ref
          .read(libraryProvider.notifier)
          .setBookSpeed(chapter.bookId, speed);
    }

    // The lock screen's estimate is derived from the speed.
    _updateAudioServiceState(state.isPlaying);

    if (state.isPlaying && state.currentChunks.isNotEmpty) {
      await _speakFrom(state.currentChunks[state.currentChunkIndex].text);
    }
  }

  Future<void> setPitch(double pitch) async {
    state = state.copyWith(playbackPitch: pitch);
    await _ttsService.setPitch(pitch);

    final db = ref.read(databaseServiceProvider);
    final stats = await db.getUserStats();
    await db.updateUserStats(stats.copyWith(preferredPitch: pitch));

    if (state.isPlaying && state.currentChunks.isNotEmpty) {
      await _speakFrom(state.currentChunks[state.currentChunkIndex].text);
    }
  }

  Future<void> setVoice(Map<String, String> voice) async {
    state = state.copyWith(voiceName: voice['name'], voiceLocale: voice['locale']);
    await _ttsService.setVoice(voice);

    _preferredVoice = voice;
    final code = primaryLanguageCode(voice['locale']);
    if (code != null) _voiceByLanguage[code] = voice;

    final db = ref.read(databaseServiceProvider);
    final stats = await db.getUserStats();
    await db.updateUserStats(stats.copyWith(
      preferredVoiceName: voice['name'],
      preferredVoiceLocale: voice['locale'],
    ));

    if (state.isPlaying && state.currentChunks.isNotEmpty) {
      await _speakFrom(state.currentChunks[state.currentChunkIndex].text);
    }
  }

  /// Stops narration. [releaseFocus] is false only when pausing for an
  /// interruption, where the audio focus request has to stay registered.
  Future<void> pause({bool releaseFocus = true}) async {
    _isStoppingForSeek = true;
    await _ttsService.stop();
    _isStoppingForSeek = false;
    _stopTimer();
    state = state.copyWith(isPlaying: false);
    _clearSpokenWord();
    _updateAudioServiceState(false);
    if (releaseFocus) {
      _pausedByInterruption = false;
      await _setSessionActive(false);
    }

    await _savePosition();
    _refreshLibraryProgress();
  }

  Future<void> resume() async {
    var chunks = state.currentChunks;
    if (chunks.isEmpty) {
      final chapter = state.currentChapter;
      if (chapter == null) return;
      chunks = chunkWithOffsets(chapter.textContent);
      if (chunks.isEmpty) return;
      state = state.copyWith(currentChunks: chunks, currentChunkIndex: 0);
    }

    final index = state.currentChunkIndex.clamp(0, chunks.length - 1);
    state = state.copyWith(isPlaying: true, currentChunkIndex: index);
    _startTimer();
    await _setSessionActive(true);
    _updateAudioServiceState(true);
    await _speakFrom(chunks[index].text);
  }

  Future<void> fastForward() async {
    if (state.currentChunks.isEmpty) return;

    int targetIndex = state.currentChunkIndex;
    int wordsSkipped = 0;
    while (wordsSkipped < 50 && targetIndex < state.currentChunks.length - 1) {
      wordsSkipped += _countWords(state.currentChunks[targetIndex].text);
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
      wordsSkipped += _countWords(state.currentChunks[targetIndex].text);
    }

    await _seekToChunk(targetIndex);
  }

  Future<void> _seekToChunk(int newIndex) async {
    if (state.currentChunks.isEmpty) return;
    final index = newIndex.clamp(0, state.currentChunks.length - 1);

    state = state.copyWith(currentChunkIndex: index);
    _clearSpokenWord();

    unawaited(_savePosition());
    _updateAudioServiceState(state.isPlaying);

    if (state.isPlaying) {
      await _speakFrom(state.currentChunks[index].text);
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
