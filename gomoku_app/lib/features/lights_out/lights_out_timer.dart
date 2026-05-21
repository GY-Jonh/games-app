import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/lights_out/constants/lights_out_constants.dart';

/// 点灯游戏倒计时 Timer（递减）
class LightsOutTimerNotifier extends StateNotifier<int> {
  Timer? _timer;

  LightsOutTimerNotifier() : super(LightsOutConstants.roundTimeSeconds);

  void start() {
    _timer?.cancel();
    state = LightsOutConstants.roundTimeSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state > 0) {
        state = state - 1;
      }
    });
  }

  void stop() {
    _timer?.cancel();
  }

  void startIfNotRunning() {
    if (_timer != null && _timer!.isActive) return;
    _timer?.cancel();
    state = LightsOutConstants.roundTimeSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state > 0) {
        state = state - 1;
      }
    });
  }

  void reset() {
    _timer?.cancel();
    state = LightsOutConstants.roundTimeSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final lightsOutTimerProvider =
    StateNotifierProvider<LightsOutTimerNotifier, int>((ref) {
  return LightsOutTimerNotifier();
});
