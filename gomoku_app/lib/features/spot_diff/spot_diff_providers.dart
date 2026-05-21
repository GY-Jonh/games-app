import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/spot_diff/models/spot_diff_set.dart';

// ========== Status Enum ==========

enum SpotDiffGameStatus {
  loading, // 正在加载图片
  selecting, // (Solo) 等待用户选择图集
  playing, // 游戏中
  won, // 己方获胜
  lost, // 己方失败
  draw, // 平局
  disconnected, // 断线
}

// ========== Game State ==========

class SpotDiffState {
  final SpotDiffGameStatus status;
  final SpotDiffSet? currentSet;
  final List<int> foundByMe; // 己方找到的差异索引
  final List<int> foundByOpponent; // 对方找到的差异索引
  final String selfName;
  final String opponentName;
  final bool isSolo;
  final int currentRound; // 当前回合（重赛时递增）

  const SpotDiffState({
    required this.status,
    this.currentSet,
    this.foundByMe = const [],
    this.foundByOpponent = const [],
    this.selfName = '',
    this.opponentName = '',
    this.isSolo = true,
    this.currentRound = 1,
  });

  int get myScore => foundByMe.length;
  int get opponentScore => foundByOpponent.length;
  int get totalDiffs => currentSet?.differences.length ?? 0;
  int get totalFound => foundByMe.length + foundByOpponent.length;
  bool get areAllFound => totalDiffs > 0 && totalFound >= totalDiffs;

  List<int> get unfoundIndices {
    if (currentSet == null) return [];
    final found = {...foundByMe, ...foundByOpponent};
    return currentSet!.differenceIndices.where((i) => !found.contains(i)).toList();
  }

  factory SpotDiffState.initial() {
    return const SpotDiffState(status: SpotDiffGameStatus.loading);
  }
}

// ========== State Notifier ==========

class SpotDiffStateNotifier extends StateNotifier<SpotDiffState> {
  SpotDiffStateNotifier() : super(SpotDiffState.initial());

  /// 启动游戏。
  void startGame(
    SpotDiffSet set, {
    bool isSolo = false,
    String selfName = '',
    String opponentName = '',
  }) {
    state = SpotDiffState(
      status: SpotDiffGameStatus.playing,
      currentSet: set,
      selfName: selfName,
      opponentName: opponentName,
      isSolo: isSolo,
      currentRound: state.currentRound,
    );
  }

  /// 尝试在 (normalizedX, normalizedY) 处找到一个差异。
  /// 返回找到的差异索引，未找到返回 null。
  int? tryFindDifference(double normalizedX, double normalizedY) {
    if (state.status != SpotDiffGameStatus.playing) return null;
    if (state.currentSet == null) return null;

    final set = state.currentSet!;
    for (final idx in state.unfoundIndices) {
      final region = set.differences[idx];
      final dx = normalizedX - region.x;
      final dy = normalizedY - region.y;
      final distance = (dx * dx + dy * dy);
      // 使用平方距离避免 sqrt 计算
      if (distance <= region.radius * region.radius) {
        // 找到差异
        state = SpotDiffState(
          status: state.status,
          currentSet: state.currentSet,
          foundByMe: [...state.foundByMe, idx],
          foundByOpponent: state.foundByOpponent,
          selfName: state.selfName,
          opponentName: state.opponentName,
          isSolo: state.isSolo,
          currentRound: state.currentRound,
        );

        // 检查是否全部找到
        if (state.areAllFound) {
          _endGame();
        }
        return idx;
      }
    }
    return null;
  }

  /// 对手找到差异。
  void opponentFoundDifference(int diffIndex) {
    if (state.status != SpotDiffGameStatus.playing) return;
    // 如果已被任一方找到，忽略重复
    if (state.foundByMe.contains(diffIndex) ||
        state.foundByOpponent.contains(diffIndex)) {
      return;
    }

    state = SpotDiffState(
      status: state.status,
      currentSet: state.currentSet,
      foundByMe: state.foundByMe,
      foundByOpponent: [...state.foundByOpponent, diffIndex],
      selfName: state.selfName,
      opponentName: state.opponentName,
      isSolo: state.isSolo,
      currentRound: state.currentRound,
    );

    if (state.areAllFound) {
      _endGame();
    }
  }

  /// 超时处理。
  void timeout() {
    if (state.status != SpotDiffGameStatus.playing) return;

    if (state.isSolo) {
      // 单人模式：超时显示当前成绩
      if (state.myScore >= state.totalDiffs) {
        state = SpotDiffState(
          status: SpotDiffGameStatus.won,
          currentSet: state.currentSet,
          foundByMe: state.foundByMe,
          foundByOpponent: state.foundByOpponent,
          selfName: state.selfName,
          opponentName: state.opponentName,
          isSolo: state.isSolo,
          currentRound: state.currentRound,
        );
      } else {
        state = SpotDiffState(
          status: SpotDiffGameStatus.lost,
          currentSet: state.currentSet,
          foundByMe: state.foundByMe,
          foundByOpponent: state.foundByOpponent,
          selfName: state.selfName,
          opponentName: state.opponentName,
          isSolo: state.isSolo,
          currentRound: state.currentRound,
        );
      }
    } else {
      // PvP 模式：比较分数
      _endGame();
    }
  }

  /// 对手超时，比较分数决定胜负。
  void opponentTimeout() {
    if (state.status != SpotDiffGameStatus.playing) return;
    _endGame();
  }

  /// 处理连接断开。
  void handleConnectionLost() {
    state = SpotDiffState(
      status: SpotDiffGameStatus.disconnected,
      currentSet: state.currentSet,
      foundByMe: state.foundByMe,
      foundByOpponent: state.foundByOpponent,
      selfName: state.selfName,
      opponentName: state.opponentName,
      isSolo: state.isSolo,
      currentRound: state.currentRound,
    );
  }

  /// 重置游戏（用于重赛）。
  void resetGame() {
    state = SpotDiffState.initial();
  }

  /// 递增回合数（重赛时）。
  void incrementRound() {
    state = SpotDiffState(
      status: SpotDiffGameStatus.loading,
      currentRound: state.currentRound + 1,
    );
  }

  /// 设置加载状态。
  void setLoading() {
    state = SpotDiffState(
      status: SpotDiffGameStatus.loading,
      currentRound: state.currentRound,
    );
  }

  void setSelecting() {
    state = SpotDiffState(
      status: SpotDiffGameStatus.selecting,
      currentRound: state.currentRound,
    );
  }

  // ========== Private ==========

  void _endGame() {
    if (state.isSolo) {
      state = SpotDiffState(
        status: state.myScore >= state.totalDiffs ? SpotDiffGameStatus.won : SpotDiffGameStatus.lost,
        currentSet: state.currentSet,
        foundByMe: state.foundByMe,
        foundByOpponent: state.foundByOpponent,
        selfName: state.selfName,
        opponentName: state.opponentName,
        isSolo: state.isSolo,
        currentRound: state.currentRound,
      );
    } else {
      if (state.myScore > state.opponentScore) {
        state = SpotDiffState(
          status: SpotDiffGameStatus.won,
          currentSet: state.currentSet,
          foundByMe: state.foundByMe,
          foundByOpponent: state.foundByOpponent,
          selfName: state.selfName,
          opponentName: state.opponentName,
          isSolo: state.isSolo,
          currentRound: state.currentRound,
        );
      } else if (state.opponentScore > state.myScore) {
        state = SpotDiffState(
          status: SpotDiffGameStatus.lost,
          currentSet: state.currentSet,
          foundByMe: state.foundByMe,
          foundByOpponent: state.foundByOpponent,
          selfName: state.selfName,
          opponentName: state.opponentName,
          isSolo: state.isSolo,
          currentRound: state.currentRound,
        );
      } else {
        state = SpotDiffState(
          status: SpotDiffGameStatus.draw,
          currentSet: state.currentSet,
          foundByMe: state.foundByMe,
          foundByOpponent: state.foundByOpponent,
          selfName: state.selfName,
          opponentName: state.opponentName,
          isSolo: state.isSolo,
          currentRound: state.currentRound,
        );
      }
    }
  }
}

// ========== Providers ==========

final spotDiffStateProvider =
    StateNotifierProvider<SpotDiffStateNotifier, SpotDiffState>((ref) {
  return SpotDiffStateNotifier();
});

/// 找茬 rematch 状态（复用五子棋模式）
enum SpotDiffRematchStatus { none, waiting, received }

final spotDiffRematchStatusProvider =
    StateProvider<SpotDiffRematchStatus>((ref) => SpotDiffRematchStatus.none);

/// 自动退出标记
final spotDiffAutoExitProvider = StateProvider<bool>((ref) => false);

/// Toast 消息
final spotDiffToastProvider = StateProvider<String?>((ref) => null);
