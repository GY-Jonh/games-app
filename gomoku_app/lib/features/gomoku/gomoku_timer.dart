import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const int gomokuTurnTimeSeconds = 60;

class GomokuTurnTimerNotifier extends StateNotifier<int> {
  Timer? _timer;

  GomokuTurnTimerNotifier() : super(gomokuTurnTimeSeconds);

  void start() {
    _timer?.cancel();
    state = gomokuTurnTimeSeconds;
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
    state = gomokuTurnTimeSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state > 0) {
        state = state - 1;
      }
    });
  }

  void reset() {
    _timer?.cancel();
    state = gomokuTurnTimeSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final gomokuTurnTimerProvider =
    StateNotifierProvider<GomokuTurnTimerNotifier, int>((ref) {
  return GomokuTurnTimerNotifier();
});
