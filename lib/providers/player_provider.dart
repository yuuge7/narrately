import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chapter.dart';
import '../services/tts_service.dart';
import 'database_provider.dart';
import 'epub_providers.dart';

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

class PlayerState {
  final Chapter? currentChapter;
  final bool isPlaying;
  final double playbackSpeed;
  final List<String> currentChunks;
  final int currentChunkIndex;

  const PlayerState({
    this.currentChapter,
    this.isPlaying = false,
    this.playbackSpeed = 1.0,
    this.currentChunks = const [],
    this.currentChunkIndex = 0,
  });

  PlayerState copyWith({
    Chapter? currentChapter,
    bool? isPlaying,
    double? playbackSpeed,
    List<String>? currentChunks,
    int? currentChunkIndex,
  }) {
    return PlayerState(
      currentChapter: currentChapter ?? this.currentChapter,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      currentChunks: currentChunks ?? this.currentChunks,
      currentChunkIndex: currentChunkIndex ?? this.currentChunkIndex,
    );
  }
}

class PlayerNotifier extends Notifier<PlayerState> {
  late TtsService _ttsService;
  bool _isStoppingForSeek = false;

  @override
  PlayerState build() {
    _ttsService = ref.watch(ttsServiceProvider);
    
    _ttsService.setCompletionHandler(() {
      _onChunkFinished();
    });
    
    _ttsService.setCancelHandler(() {
      if (!_isStoppingForSeek) {
        state = state.copyWith(isPlaying: false);
      }
    });

    return const PlayerState();
  }
  
  List<String> _chunkText(String text) {
    // Split by sentence endings (. ! ?) followed by space or newline
    // We use a regex that keeps the punctuation with the sentence.
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
    
    // Add any remaining text not matched by regex (e.g. string without ending punctuation)
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
      // Play next chunk
      state = state.copyWith(currentChunkIndex: state.currentChunkIndex + 1);
      await _ttsService.speak(state.currentChunks[state.currentChunkIndex]);
    } else {
      // End of chapter
      await _onChapterFinished();
    }
  }

  Future<void> _onChapterFinished() async {
    final chapter = state.currentChapter;
    if (chapter == null) {
      state = state.copyWith(isPlaying: false);
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
      state = state.copyWith(isPlaying: false);
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
    // Note: setSpeechRate does not restart playback, some TTS engines apply it to the next utterance.
    // If currently playing, we might want to restart the current chunk to apply immediately, 
    // but the next chunk will pick it up anyway. To be safe, we restart current chunk.
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
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    if (state.currentChunks.isNotEmpty && state.currentChunkIndex < state.currentChunks.length) {
      state = state.copyWith(isPlaying: true);
      await _ttsService.speak(state.currentChunks[state.currentChunkIndex]);
    }
  }

  Future<void> fastForward() async {
    if (state.currentChunks.isEmpty) return;
    
    // Approximate 15s by advancing a few chunks (e.g. 50 words). 
    // Let's count words forward.
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
