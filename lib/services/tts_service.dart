import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  TtsService() {
    _initTts();
  }

  void _initTts() {
    // We can handle platform specific initializations if any,
    // though for simple usage on Android, it's mostly ready.
  }

  void setCompletionHandler(VoidCallback handler) {
    _flutterTts.setCompletionHandler(handler);
  }
  
  void setCancelHandler(VoidCallback handler) {
    _flutterTts.setCancelHandler(handler);
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> pause() async {
    // flutter_tts pause is mostly supported on iOS/Web/macOS out of the box,
    // On Android, pause() only works if synthesized to file or specific engines,
    // but flutter_tts 4.0+ adds stop() which halts it. We will call pause() and
    // see if it works, otherwise stop() is the reliable fallback.
    // However, pause() might not be perfectly supported by all Android TTS engines.
    await _flutterTts.pause();
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  Future<void> setSpeechRate(double rate) async {
    // flutter_tts speech rate: 0.0 to 1.0. 
    // Android default is 0.5 for normal, 1.0 is 2x. 
    // We map 1.0x to 0.5.
    await _flutterTts.setSpeechRate(rate * 0.5);
  }
}
