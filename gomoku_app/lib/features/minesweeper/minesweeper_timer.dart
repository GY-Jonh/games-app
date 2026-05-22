import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/minesweeper/constants/minesweeper_constants.dart';

class MinesweeperTimerNotifier extends StateNotifier<int> {
  Timer? _timer;

  MinesweeperTimerNotifier() : super(MinesweeperConstants.roundTimeSeconds);

  void start() {
    _timer?.cancel();
    state = MinesweeperConstants.roundTimeSeconds;
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
    state = MinesweeperConstants.roundTimeSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state > 0) state = state - 1;
    });
  }

  void reset() {
    _timer?.cancel();
    state = MinesweeperConstants.roundTimeSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final minesweeperTimerProvider =
    StateNotifierProvider<MinesweeperTimerNotifier, int>((ref) {
  return MinesweeperTimerNotifier();
});
