import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/game_2048/constants/game_2048_constants.dart';

/// 2048 游戏倒计时 Timer（递减）
class Game2048TimerNotifier extends StateNotifier<int> {
  Timer? _timer;

  Game2048TimerNotifier() : super(Game2048Constants.roundTimeSeconds);

  void start() {
    _timer?.cancel();
    state = Game2048Constants.roundTimeSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state > 0) state = state - 1;
    });
  }

  void stop() {
    _timer?.cancel();
  }

  void startIfNotRunning() {
    if (_timer != null && _timer!.isActive) return;
    _timer?.cancel();
    state = Game2048Constants.roundTimeSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state > 0) state = state - 1;
    });
  }

  void reset() {
    _timer?.cancel();
    state = Game2048Constants.roundTimeSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final game2048TimerProvider =
    StateNotifierProvider<Game2048TimerNotifier, int>((ref) {
  return Game2048TimerNotifier();
});
