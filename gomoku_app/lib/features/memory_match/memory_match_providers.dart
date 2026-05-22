import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/memory_match/constants/memory_match_constants.dart';

// ========== Status Enum ==========

enum MemoryMatchGameStatus {
  loading,
  playing,
  won,
  lost,
  draw,
  disconnected,
}

// ========== Game State ==========

class MemoryMatchState {
  final MemoryMatchGameStatus status;
  final List<int> cardValues; // 16 个值，每种 0-7 出现两次
  final Set<int> matchedPositions; // 已永久匹配的位置
  final int? firstSelected; // 本回合第一次选中的位置
  final int? secondSelected; // 本回合第二次选中的位置
  final int seed;
  final bool isSolo;
  final String selfName;
  final String opponentName;
  final int currentRound;
  final int moveCount;

  const MemoryMatchState({
    required this.status,
    this.cardValues = const [],
    this.matchedPositions = const {},
    this.firstSelected,
    this.secondSelected,
    this.seed = 0,
    this.isSolo = true,
    this.selfName = '',
    this.opponentName = '',
    this.currentRound = 1,
    this.moveCount = 0,
  });

  /// 判断某位置是否已匹配
  bool isMatched(int position) => matchedPositions.contains(position);

  /// 判断某位置是否当前正面显示（匹配的或临时翻开的）
  bool isRevealed(int position) =>
      matchedPositions.contains(position) ||
      firstSelected == position ||
      secondSelected == position;

  /// 获取该位置卡面对应的符号
  String getSymbol(int position) {
    if (position < 0 || position >= cardValues.length) return '?';
    final value = cardValues[position];
    if (value < 0 || value >= MemoryMatchConstants.cardSymbols.length) {
      return '?';
    }
    return MemoryMatchConstants.cardSymbols[value];
  }

  /// 判断是否所有卡片都已匹配（获胜）
  bool get isAllMatched =>
      matchedPositions.length == MemoryMatchConstants.totalCards;

  factory MemoryMatchState.initial() {
    return const MemoryMatchState(status: MemoryMatchGameStatus.loading);
  }
}

// ========== State Notifier ==========

class MemoryMatchStateNotifier extends StateNotifier<MemoryMatchState> {
  MemoryMatchStateNotifier() : super(MemoryMatchState.initial());

  // ========== Static Card Generation ==========

  /// 根据 seed 生成随机的卡片排列
  static List<int> generateCards(int seed) {
    final random = Random(seed);
    final cards = <int>[];
    for (int i = 0; i < MemoryMatchConstants.pairCount; i++) {
      cards.add(i);
      cards.add(i);
    }
    cards.shuffle(random);
    return cards;
  }

  // ========== Public Methods ==========

  /// 用指定 seed 生成棋盘并开始游戏
  void startGame({
    required int seed,
    bool isSolo = false,
    String selfName = '',
    String opponentName = '',
  }) {
    final cards = generateCards(seed);
    state = MemoryMatchState(
      status: MemoryMatchGameStatus.playing,
      cardValues: cards,
      seed: seed,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
      currentRound: state.currentRound,
    );
  }

  /// 直接使用指定卡片列表开始游戏
  void startGameWithCards({
    required List<int> cards,
    required int seed,
    bool isSolo = false,
    String selfName = '',
    String opponentName = '',
  }) {
    state = MemoryMatchState(
      status: MemoryMatchGameStatus.playing,
      cardValues: List.of(cards),
      seed: seed,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
      currentRound: state.currentRound,
    );
  }

  /// 选择一张卡片，返回 true 表示这是第二张选择（需要进入校验流程）
  bool selectCard(int position) {
    if (state.status != MemoryMatchGameStatus.playing) return false;
    if (state.matchedPositions.contains(position)) return false;
    if (state.firstSelected == position) return false;

    if (state.firstSelected == null) {
      // 第一次选择
      state = MemoryMatchState(
        status: MemoryMatchGameStatus.playing,
        cardValues: state.cardValues,
        matchedPositions: state.matchedPositions,
        firstSelected: position,
        secondSelected: null,
        seed: state.seed,
        isSolo: state.isSolo,
        selfName: state.selfName,
        opponentName: state.opponentName,
        currentRound: state.currentRound,
        moveCount: state.moveCount,
      );
      return false;
    }

    // 第二次选择
    state = MemoryMatchState(
      status: MemoryMatchGameStatus.playing,
      cardValues: state.cardValues,
      matchedPositions: state.matchedPositions,
      firstSelected: state.firstSelected,
      secondSelected: position,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount + 1,
    );
    return true;
  }

  /// 校验当前两张选中卡片是否匹配
  /// 返回 true 表示匹配成功
  bool resolveSelection() {
    final first = state.firstSelected;
    final second = state.secondSelected;
    if (first == null || second == null) return false;

    final matched = state.cardValues[first] == state.cardValues[second];
    if (matched) {
      final newMatched = {...state.matchedPositions, first, second};
      final won = newMatched.length == MemoryMatchConstants.totalCards;
      state = MemoryMatchState(
        status: won
            ? MemoryMatchGameStatus.won
            : MemoryMatchGameStatus.playing,
        cardValues: state.cardValues,
        matchedPositions: newMatched,
        firstSelected: null,
        secondSelected: null,
        seed: state.seed,
        isSolo: state.isSolo,
        selfName: state.selfName,
        opponentName: state.opponentName,
        currentRound: state.currentRound,
        moveCount: state.moveCount,
      );
      return true;
    } else {
      state = MemoryMatchState(
        status: MemoryMatchGameStatus.playing,
        cardValues: state.cardValues,
        matchedPositions: state.matchedPositions,
        firstSelected: null,
        secondSelected: null,
        seed: state.seed,
        isSolo: state.isSolo,
        selfName: state.selfName,
        opponentName: state.opponentName,
        currentRound: state.currentRound,
        moveCount: state.moveCount,
      );
      return false;
    }
  }

  /// 对手获胜
  void opponentWon() {
    if (state.status != MemoryMatchGameStatus.playing) return;
    if (state.isSolo) return;

    state = MemoryMatchState(
      status: MemoryMatchGameStatus.lost,
      cardValues: state.cardValues,
      matchedPositions: state.matchedPositions,
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
    if (state.status != MemoryMatchGameStatus.playing) return;

    state = MemoryMatchState(
      status: state.isSolo
          ? MemoryMatchGameStatus.lost
          : MemoryMatchGameStatus.draw,
      cardValues: state.cardValues,
      matchedPositions: state.matchedPositions,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount,
    );
  }

  /// 对手超时（PvP）
  void opponentTimeout() {
    if (state.status != MemoryMatchGameStatus.playing) return;
    state = MemoryMatchState(
      status: MemoryMatchGameStatus.won,
      cardValues: state.cardValues,
      matchedPositions: state.matchedPositions,
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
    state = MemoryMatchState(
      status: MemoryMatchGameStatus.disconnected,
      cardValues: state.cardValues,
      matchedPositions: state.matchedPositions,
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
    state = MemoryMatchState.initial();
  }

  /// 递增回合数（重赛时）
  void incrementRound() {
    state = MemoryMatchState(
      status: MemoryMatchGameStatus.loading,
      currentRound: state.currentRound + 1,
    );
  }

  /// 设置加载状态
  void setLoading() {
    state = MemoryMatchState(
      status: MemoryMatchGameStatus.loading,
      currentRound: state.currentRound,
    );
  }

  /// 生成随机 seed
  static int generateSeed() {
    return DateTime.now().millisecondsSinceEpoch ^ (Random().nextInt(1 << 16));
  }
}

// ========== Providers ==========

final memoryMatchStateProvider =
    StateNotifierProvider<MemoryMatchStateNotifier, MemoryMatchState>((ref) {
  return MemoryMatchStateNotifier();
});

/// 重赛状态
enum MemoryMatchRematchStatus { none, waiting, received }

final memoryMatchRematchStatusProvider =
    StateProvider<MemoryMatchRematchStatus>(
        (ref) => MemoryMatchRematchStatus.none);

/// 自动退出标记
final memoryMatchAutoExitProvider = StateProvider<bool>((ref) => false);

/// Toast 消息
final memoryMatchToastProvider = StateProvider<String?>((ref) => null);
