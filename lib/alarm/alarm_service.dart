import 'package:audioplayers/audioplayers.dart';

class AlarmService {
  static final AudioPlayer _player = AudioPlayer();
  static bool isPlaying = false;

  static Future<void> play(String sound) async {
    if (isPlaying) return;

    isPlaying = true;

    await _player.setReleaseMode(ReleaseMode.loop);

    await _player.play(
      AssetSource('sounds/$sound.mp3'),
      volume: 1.0,
    );
  }

  static Future<void> stop() async {
    isPlaying = false;
    await _player.stop();
  }
}
