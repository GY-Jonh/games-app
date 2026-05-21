import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/spot_diff/constants/spot_diff_constants.dart';

class SpotDiffTimerNotifier extends StateNotifier<int> {
  Timer? _timer;

  SpotDiffTimerNotifier() : super(spotDiffRoundTimeSeconds);

  void start() {
    _timer?.cancel();
    state = spotDiffRoundTimeSeconds;
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
    state = spotDiffRoundTimeSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state > 0) {
        state = state - 1;
      }
    });
  }

  void reset() {
    _timer?.cancel();
    state = spotDiffRoundTimeSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final spotDiffTimerProvider =
    StateNotifierProvider<SpotDiffTimerNotifier, int>((ref) {
  return SpotDiffTimerNotifier();
});
