import 'package:audioplayers/audioplayers.dart';

import 'batch_feedback_stub.dart';

export 'batch_feedback_stub.dart' show BatchFeedbackKind;

class BatchFeedbackPlayer {
  final AudioPlayer _player = AudioPlayer();

  Future<void> prepare() => _player.setVolume(0.35);

  Future<void> play(BatchFeedbackKind kind) async {
    final repetitions = switch (kind) {
      BatchFeedbackKind.success => 1,
      BatchFeedbackKind.duplicate => 2,
      BatchFeedbackKind.notFound => 3,
      BatchFeedbackKind.error => 4,
    };
    for (var index = 0; index < repetitions; index++) {
      await _player.stop();
      await _player.play(AssetSource('sounds/beep.mp3'));
      if (index + 1 < repetitions) {
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }
    }
  }

  Future<void> dispose() => _player.dispose();
}
