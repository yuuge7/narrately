import 'package:audio_service/audio_service.dart';

/// Bridges the notification and lock-screen controls to `PlayerNotifier`.
///
/// audio_service normally drives a real player; here the audio comes from the
/// TTS engine instead, so this handler owns no playback of its own and only
/// relays intents through callbacks. `PlayerNotifier` pushes state back the
/// other way by adding to [playbackState] and [mediaItem].
class NarratelyAudioHandler extends BaseAudioHandler {
  void Function()? onPlay;
  void Function()? onPause;
  void Function()? onStop;
  void Function()? onFastForward;
  void Function()? onRewind;
  void Function()? onSkipToNext;
  void Function()? onSkipToPrevious;
  void Function(Duration position)? onSeek;

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

  @override
  Future<void> seek(Duration position) async {
    onSeek?.call(position);
  }
}

NarratelyAudioHandler? audioHandler;

Future<void> initAudioService() async {
  audioHandler = await AudioService.init(
    builder: () => NarratelyAudioHandler(),
    config: const AudioServiceConfig(
      // Matches the application id. The old value named a package this app
      // has never had, which is what the channel shows under in Android's
      // notification settings.
      androidNotificationChannelId: 'com.yuuge7.narrately.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
}
