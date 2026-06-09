/// 扑克收集战 — 状态管理与 AI 对手。
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/card_battle/card_battle_engine.dart';
import 'package:gomoku_app/features/card_battle/constants/card_battle_constants.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_card.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_state.dart';

// ========== Provider 定义 ==========

final cardBattleStateProvider =
    StateNotifierProvider<CardBattleStateNotifier, CardBattleState>((ref) {
  return CardBattleStateNotifier();
});

final cardBattleAutoExitProvider = StateProvider<bool>((ref) => false);
final cardBattleToastProvider = StateProvider<String?>((ref) => null);

// ========== 选牌状态（UI 用，不放入不可变状态） ==========

final cardBattleSelectedProvider = StateProvider<List<int>>((ref) => []);

// ========== StateNotifier ==========

class CardBattleStateNotifier extends StateNotifier<CardBattleState> {
  CardBattleEngine? _engine;
  Timer? _aiTimer;
  Timer? _phaseTimer;
  Timer? _opponentTimer;

  // PvP 回调（由 handler 设置）
  void Function(Map<String, dynamic> action)? onActionNeeded;
  /// PvP Guest 发送操作到 Host 的回调。
  void Function(String action, List<Map<String, dynamic>>? cards)? onGuestActionNeeded;
  /// PvP 重赛回调（由 handler 设置）。
  void Function()? onRematch;

  CardBattleStateNotifier() : super(CardBattleState.initial());

  static int generateSeed() => Random().nextInt(1 << 31);

  // ========== 关卡启动 ==========

  void startGame({
    required int seed,
    required bool isSolo,
    required String selfName,
    String opponentName = '',
  }) {
    _aiTimer?.cancel();
    _phaseTimer?.cancel();
    _opponentTimer?.cancel();
    _engine = null;

    final firstPlayer = Random(seed).nextInt(2);
    _engine = CardBattleEngine(seed, firstPlayer);
    _engine!.initGame();

    state = _engine!.toSnapshot(
      phase: _engine!.turnPlayerIndex == 0
          ? CardBattlePhase.playerTurn
          : CardBattlePhase.opponentTurn,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
    );

    // 如果对手先手，AI 自动出牌
    if (_engine!.turnPlayerIndex == 1 && isSolo) {
      _scheduleAiTurn();
    }
  }

  /// 重赛 — 单人直接重启，PvP 走 handler 的重赛流程。
  void rematch() {
    _aiTimer?.cancel();
    _phaseTimer?.cancel();
    _opponentTimer?.cancel();

    if (state.isSolo) {
      final seed = generateSeed();
      startGame(
        seed: seed,
        isSolo: true,
        selfName: state.selfName,
        opponentName: state.opponentName,
      );
    } else if (onRematch != null) {
      onRematch!();
    }
  }

  // ========== 玩家操作 ==========

  /// 玩家出选中的牌。
  void playerPlay(List<GameCard> selectedCards) {
    // PvP Guest 模式：没有 engine，通过回调发送操作给 Host
    if (!state.isSolo && _engine == null) {
      if (onGuestActionNeeded != null) {
        onGuestActionNeeded!(
          'play',
          selectedCards.map((c) => c.toJson()).toList(),
        );
        state = state.copyWith(phase: CardBattlePhase.opponentTurn);
        _resetOpponentTimer();
      }
      return;
    }
    if (_engine == null) return;
    if (!state.isPlayerTurn) return;

    final success = _engine!.playerPlay(selectedCards);
    if (!success) return;  // 无效牌型或不能管上，手牌保持选中作为提示

    _updateState(CardBattlePhase.opponentTurn);

    if (state.isSolo && !state.isGameOver) {
      _scheduleAiTurn();
    }
  }

  /// 玩家"过"。
  void playerPass() {
    // PvP Guest 模式：没有 engine，通过回调发送操作给 Host
    if (!state.isSolo && _engine == null) {
      if (onGuestActionNeeded != null) {
        onGuestActionNeeded!('pass', null);
        state = state.copyWith(phase: CardBattlePhase.opponentTurn);
        _resetOpponentTimer();
      }
      return;
    }
    if (_engine == null) return;
    if (!state.canPass) return;
    if (state.turnPlayerIndex != 0) return;

    _engine!.playerPass();
    // pass 后对手赢下本轮，对手先出
    _updateState(CardBattlePhase.opponentTurn);

    if (state.isGameOver) return;

    // 对手先出，调度 AI
    if (state.isSolo && _engine!.turnPlayerIndex == 1) {
      _scheduleAiTurn();
    }
  }

  // ========== AI 对手逻辑 ==========

  void _scheduleAiTurn() {
    _aiTimer?.cancel();
    final delay = CardBattleConstants.aiDelayMinMs +
        Random().nextInt(CardBattleConstants.aiDelayMaxMs -
            CardBattleConstants.aiDelayMinMs +
            1);
    _aiTimer = Timer(Duration(milliseconds: delay), _executeAiTurn);
  }

  void _executeAiTurn() {
    if (_engine == null) return;
    if (state.phase == CardBattlePhase.roundEnd ||
        state.phase == CardBattlePhase.gameOver) return;
    if (_engine!.turnPlayerIndex != 1) return;

    state = state.copyWith(phase: CardBattlePhase.opponentTurn);

    final result = _engine!.aiPlay();
    final action = result['action'] as String;

    if (action == 'pass') {
      _updateState(CardBattlePhase.playerTurn);
      // 玩家赢下本轮，轮到玩家出牌
    } else {
      _updateState(CardBattlePhase.playerTurn);
      // 对手出完牌后轮到玩家
    }

    if (state.isGameOver) return;

    // 如果仍然是对手回合（收牌后对手先手），继续 AI
    if (_engine!.turnPlayerIndex == 1 &&
        !state.isGameOver &&
        state.isSolo) {
      _scheduleAiTurn();
    }
  }

  // ========== 状态刷新 ==========

  void _updateState(CardBattlePhase phase) {
    if (_engine == null) return;
    state = _engine!.toSnapshot(
      phase: phase,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
    );
    _notifyAction(phase);
    _resetOpponentTimer();
  }

 // ========== PvP 相关 ==========

  void _notifyAction(CardBattlePhase phase) {
    if (!state.isSolo && onActionNeeded != null) {
      onActionNeeded!({
        'phase': phase.name,
        'turnPlayerIndex': _engine?.turnPlayerIndex,
      });
    }
  }

  /// PvP: 等待对手超时定时器管理。
  void _resetOpponentTimer() {
    _opponentTimer?.cancel();
    if (state.isSolo || state.isGameOver) return;
    if (state.phase == CardBattlePhase.opponentTurn &&
        state.status == CardBattleStatus.playing) {
      _opponentTimer = Timer(
        Duration(milliseconds: CardBattleConstants.opponentTimeoutMs),
        () {
          if (!state.isGameOver && state.status == CardBattleStatus.playing) {
            handleConnectionLost();
          }
        },
      );
    }
  }

  /// PvP: 对手（Guest）"过"。
  void opponentPass() {
    if (_engine == null) return;
    if (_engine!.turnPlayerIndex != 1) return;
    _engine!.opponentPass();
    _updateState(CardBattlePhase.playerTurn);
  }

  /// PvP: 对手（Guest）出牌。
  void opponentPlay(List<GameCard> cards) {
    if (_engine == null) return;
    if (_engine!.turnPlayerIndex != 1) return;
    _engine!.opponentPlay(cards);
    _updateState(CardBattlePhase.playerTurn);
  }

  /// PvP: Guest 接收 Host 发来的远程状态快照。
  void applyRemoteState(CardBattleState remoteState) {
    _aiTimer?.cancel();
    // 保留 Guest 本地的身份信息（Host 发送的状态中名字是 Host 视角的）
    state = remoteState.copyWith(
      selfName: state.selfName,
      opponentName: state.opponentName,
    );
    _resetOpponentTimer();
  }

  /// PvP: Guest 接收 Host 发来的新回合初始状态。
  void applyRoundStart({
    required int seed,
    required List<GameCard> playerCards,
    required List<GameCard> opponentCards,
    required String selfName,
    required String opponentName,
    int turnPlayerIndex = 0,
  }) {
    _aiTimer?.cancel();
    state = CardBattleState(
      phase: turnPlayerIndex == 0
          ? CardBattlePhase.playerTurn
          : CardBattlePhase.opponentTurn,
      status: CardBattleStatus.playing,
      deck: [],
      playerHand: List.from(playerCards),
      opponentHand: List.from(opponentCards),
      tableCards: [],
      playerTableCards: [],
      opponentTableCards: [],
      lastPlayWasPass: false,
      playerCollected: [],
      opponentCollected: [],
      firstPlayer: turnPlayerIndex,
      turnPlayerIndex: turnPlayerIndex,
      seed: seed,
      isSolo: false,
      selfName: selfName,
      opponentName: opponentName,
      roundNumber: 1,
      lastRoundPassed: false,
    );
    _resetOpponentTimer();
  }

  /// 重置游戏（新一局）。
  void resetGame() {
    _aiTimer?.cancel();
    _phaseTimer?.cancel();
    _opponentTimer?.cancel();
    _engine = null;
    onActionNeeded = null;
    state = CardBattleState.initial();
  }

  // ========== 断线 / 清理 ==========

  void handleConnectionLost() {
    _aiTimer?.cancel();
    _opponentTimer?.cancel();
    _engine?.forceGameOver();
    state = _engine?.toSnapshot(
          phase: CardBattlePhase.gameOver,
          isSolo: state.isSolo,
          selfName: state.selfName,
          opponentName: state.opponentName,
        ) ??
        state.copyWith(
          status: CardBattleStatus.disconnected,
          resultMessage: '连接已断开',
        );
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _phaseTimer?.cancel();
    _opponentTimer?.cancel();
    super.dispose();
  }
}
