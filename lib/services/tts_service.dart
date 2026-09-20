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
  
  void setErrorHandler(void Function(dynamic message) handler) {
    _flutterTts.setErrorHandler(handler);
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate * 0.5);
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  Future<List<Map<String, String>>> getVoices() async {
    final voices = await _flutterTts.getVoices;
    if (voices == null) return [];
    
    return (voices as List).map((v) {
      return {
        'name': v['name'] as String,
        'locale': v['locale'] as String,
      };
    }).toList();
  }

  Future<void> setVoice(Map<String, String> voice) async {
    await _flutterTts.setVoice(voice);
  }
}
