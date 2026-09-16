import 'package:audio_service/audio_service.dart';

class NarratelyAudioHandler extends BaseAudioHandler {
  // We don't implement the full audio_service backend here directly using just_audio.
  // Instead, this handler simply relays commands to our PlayerNotifier,
  // and our PlayerNotifier updates this handler with the current state.
  
  // Actually, audio_service expects the AudioHandler to receive intents from the OS
  // and we can either stream state changes from PlayerNotifier to AudioHandler,
  // or we can put the commands here. Since Riverpod is outside of this, we will
  // inject callbacks or a Riverpod ProviderContainer into the handler, or just use 
  // streams. A simple way is to define functional callbacks.
  
  Function()? onPlay;
  Function()? onPause;
  Function()? onStop;
  Function()? onFastForward;
  Function()? onRewind;
  Function()? onSkipToNext;
  Function()? onSkipToPrevious;

  @override
  Future<void> play() async {
    onPlay?.call();
  }

  @override
  Future<void> pause() async {
    onPause?.call();
  }

  @override
  Future<void> stop() async {
    onStop?.call();
    await super.stop();
  }
  
  @override
  Future<void> fastForward() async {
    onFastForward?.call();
  }
  
  @override
  Future<void> rewind() async {
    onRewind?.call();
  }

  @override
  Future<void> skipToNext() async {
    onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPrevious?.call();
  }
}

NarratelyAudioHandler? audioHandler;

Future<void> initAudioService() async {
  audioHandler = await AudioService.init(
    builder: () => NarratelyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.ebooklisten.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
