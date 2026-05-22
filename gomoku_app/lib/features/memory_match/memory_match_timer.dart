import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/memory_match/constants/memory_match_constants.dart';

/// 记忆翻牌倒计时 Timer（递减）
class MemoryMatchTimerNotifier extends StateNotifier<int> {
  Timer? _timer;

  MemoryMatchTimerNotifier() : super(MemoryMatchConstants.roundTimeSeconds);

  void start() {
    _timer?.cancel();
    state = MemoryMatchConstants.roundTimeSeconds;
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
    state = MemoryMatchConstants.roundTimeSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state > 0) {
        state = state - 1;
      }
    });
  }

  void reset() {
    _timer?.cancel();
    state = MemoryMatchConstants.roundTimeSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final memoryMatchTimerProvider =
    StateNotifierProvider<MemoryMatchTimerNotifier, int>((ref) {
  return MemoryMatchTimerNotifier();
});
