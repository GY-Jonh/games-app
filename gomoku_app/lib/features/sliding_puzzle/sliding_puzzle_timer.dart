import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/sliding_puzzle/constants/sliding_puzzle_constants.dart';

/// 数字华容道倒计时 Timer
class SlidingPuzzleTimerNotifier extends StateNotifier<int> {
  Timer? _timer;

  SlidingPuzzleTimerNotifier()
      : super(SlidingPuzzleConstants.roundTimeSeconds);

  void start() {
    _timer?.cancel();
    state = SlidingPuzzleConstants.roundTimeSeconds;
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
    state = SlidingPuzzleConstants.roundTimeSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state > 0) state = state - 1;
    });
  }

  void reset() {
    _timer?.cancel();
    state = SlidingPuzzleConstants.roundTimeSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final slidingPuzzleTimerProvider =
    StateNotifierProvider<SlidingPuzzleTimerNotifier, int>((ref) {
  return SlidingPuzzleTimerNotifier();
});
