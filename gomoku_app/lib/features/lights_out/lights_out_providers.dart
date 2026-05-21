import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/lights_out/constants/lights_out_constants.dart';

// ========== Status Enum ==========

enum LightsOutGameStatus {
  loading,
  playing,
  won,
  lost,
  draw,
  disconnected,
}

// ========== Game State ==========

class LightsOutState {
  final LightsOutGameStatus status;
  final int gridBits; // 25-bit board state
  final int seed; // Random seed for board generation
  final bool isSolo;
  final String selfName;
  final String opponentName;
  final int currentRound;
  final int moveCount;

  const LightsOutState({
    required this.status,
    this.gridBits = 0,
    this.seed = 0,
    this.isSolo = true,
    this.selfName = '',
    this.opponentName = '',
    this.currentRound = 1,
    this.moveCount = 0,
  });

  /// 获取 (row, col) 位置灯的状态，true=亮
  bool isLit(int row, int col) {
    final index = row * LightsOutConstants.gridSize + col;
    return (gridBits & (1 << index)) != 0;
  }

  factory LightsOutState.initial() {
    return const LightsOutState(status: LightsOutGameStatus.loading);
  }
}

// ========== State Notifier ==========

class LightsOutStateNotifier extends StateNotifier<LightsOutState> {
  LightsOutStateNotifier() : super(LightsOutState.initial());

  // ========== Static Board Logic ==========

  /// 根据 seed 生成可解的棋盘（25-bit int）
  static int generateBoardBits(int seed) {
    final random = Random(seed);
    final movesCount = LightsOutConstants.minMovesToGenerate +
        random.nextInt(LightsOutConstants.maxMovesToGenerate -
            LightsOutConstants.minMovesToGenerate +
            1);
    int bits = 0;
    for (int i = 0; i < movesCount; i++) {
      final r = random.nextInt(LightsOutConstants.gridSize);
      final c = random.nextInt(LightsOutConstants.gridSize);
      bits ^= _computeToggleMask(r, c);
    }
    // 极低概率下可能生成全灭棋盘（gridBits == 0），强制固定翻转
    if (isWon(bits)) {
      bits = _computeToggleMask(0, 0);
    }
    return bits;
  }

  /// 计算 (row, col) 位置的翻转掩码
  static int _computeToggleMask(int row, int col) {
    final size = LightsOutConstants.gridSize;
    int mask = 0;
    // self
    mask |= 1 << (row * size + col);
    // up
    if (row > 0) mask |= 1 << ((row - 1) * size + col);
    // down
    if (row < size - 1) mask |= 1 << ((row + 1) * size + col);
    // left
    if (col > 0) mask |= 1 << (row * size + (col - 1));
    // right
    if (col < size - 1) mask |= 1 << (row * size + (col + 1));
    return mask;
  }

  /// 判断是否获胜（全灭）
  static bool isWon(int gridBits) => gridBits == 0;

  // ========== Methods ==========

  /// 用指定 seed 生成棋盘并开始游戏
  void startGame({
    required int seed,
    bool isSolo = false,
    String selfName = '',
    String opponentName = '',
  }) {
    final bits = generateBoardBits(seed);
    state = LightsOutState(
      status: LightsOutGameStatus.playing,
      gridBits: bits,
      seed: seed,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
      currentRound: state.currentRound,
    );
  }

  /// 直接使用指定 bits 开始游戏（Guest 收到 seed 时使用）
  void startGameWithBits({
    required int bits,
    required int seed,
    bool isSolo = false,
    String selfName = '',
    String opponentName = '',
  }) {
    state = LightsOutState(
      status: LightsOutGameStatus.playing,
      gridBits: bits,
      seed: seed,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
      currentRound: state.currentRound,
    );
  }

  /// 点击 (row, col)，翻转自身和邻居。
  /// 返回 true 表示获胜。
  bool toggle(int row, int col) {
    if (state.status != LightsOutGameStatus.playing) return false;

    final mask = _computeToggleMask(row, col);
    final newBits = state.gridBits ^ mask;
    final won = isWon(newBits);

    state = LightsOutState(
      status: won ? LightsOutGameStatus.won : LightsOutGameStatus.playing,
      gridBits: newBits,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount + 1,
    );

    return won;
  }

  /// 对手获胜
  void opponentWon() {
    if (state.status != LightsOutGameStatus.playing) return;
    if (state.isSolo) return;

    state = LightsOutState(
      status: LightsOutGameStatus.lost,
      gridBits: state.gridBits,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount,
    );
  }

  /// 超时处理
  void timeout() {
    if (state.status != LightsOutGameStatus.playing) return;

    if (state.isSolo) {
      // 单人模式：超时判负
      state = LightsOutState(
        status: LightsOutGameStatus.lost,
        gridBits: state.gridBits,
        seed: state.seed,
        isSolo: state.isSolo,
        selfName: state.selfName,
        opponentName: state.opponentName,
        currentRound: state.currentRound,
        moveCount: state.moveCount,
      );
    } else {
      // PvP 模式：超时平局
      state = LightsOutState(
        status: LightsOutGameStatus.draw,
        gridBits: state.gridBits,
        seed: state.seed,
        isSolo: state.isSolo,
        selfName: state.selfName,
        opponentName: state.opponentName,
        currentRound: state.currentRound,
        moveCount: state.moveCount,
      );
    }
  }

  /// 对手超时（PvP）
  void opponentTimeout() {
    if (state.status != LightsOutGameStatus.playing) return;
    state = LightsOutState(
      status: LightsOutGameStatus.won,
      gridBits: state.gridBits,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount,
    );
  }

  /// 连接断开
  void handleConnectionLost() {
    state = LightsOutState(
      status: LightsOutGameStatus.disconnected,
      gridBits: state.gridBits,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount,
    );
  }

  /// 重置游戏
  void resetGame() {
    state = LightsOutState.initial();
  }

  /// 递增回合数（重赛时）
  void incrementRound() {
    state = LightsOutState(
      status: LightsOutGameStatus.loading,
      currentRound: state.currentRound + 1,
    );
  }

  /// 设置加载状态
  void setLoading() {
    state = LightsOutState(
      status: LightsOutGameStatus.loading,
      currentRound: state.currentRound,
    );
  }

  /// 生成随机 seed
  static int generateSeed() {
    return DateTime.now().millisecondsSinceEpoch ^ (Random().nextInt(1 << 16));
  }
}

// ========== Providers ==========

final lightsOutStateProvider =
    StateNotifierProvider<LightsOutStateNotifier, LightsOutState>((ref) {
  return LightsOutStateNotifier();
});

/// 重赛状态
enum LightsOutRematchStatus { none, waiting, received }

final lightsOutRematchStatusProvider =
    StateProvider<LightsOutRematchStatus>((ref) => LightsOutRematchStatus.none);

/// 自动退出标记
final lightsOutAutoExitProvider = StateProvider<bool>((ref) => false);

/// Toast 消息
final lightsOutToastProvider = StateProvider<String?>((ref) => null);
