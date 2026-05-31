/// 炸金花状态管理 + AI 决策。
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/zha_jinhua/constants/zha_jinhua_constants.dart';
import 'package:gomoku_app/features/zha_jinhua/models/playing_card.dart';
import 'package:gomoku_app/features/zha_jinhua/models/zha_jinhua_state.dart';

// ========== 重赛状态 ==========

enum ZhaJinhuaRematchStatus { none, waiting, received }

/// AI 动作类型。
enum AiAction { peek, call, raise, fold, compare }

// ========== StateNotifier ==========

class ZhaJinhuaStateNotifier extends StateNotifier<ZhaJinhuaState> {
  Timer? _aiTimer;

  // PvP 回调 (由 handler 设置)
  void Function(Map<String, dynamic> action)? onActionNeeded;

  ZhaJinhuaStateNotifier() : super(ZhaJinhuaState.initial());

  static int generateSeed() => Random().nextInt(1 << 31);

  // ========== 游戏生命周期 ==========

  /// 开始游戏。PvP 中 Host 传入双方手牌，Guest 只传入自己的手牌。
  void startGame({
    required int seed,
    required bool isSolo,
    required String selfName,
    String opponentName = '',
    List<PlayingCard>? playerCards,
    List<PlayingCard>? opponentCards,
    int playerChips = ZhaJinhuaConstants.initialChips,
    int opponentChips = ZhaJinhuaConstants.initialChips,
  }) {
    _aiTimer?.cancel();
    _aiTimer = null;

    final pCards = playerCards ?? Deck.dealHand(seed, 0);
    final oCards = opponentCards ?? Deck.dealHand(seed, 1);

    state = ZhaJinhuaState(
      phase: ZhaJinhuaPhase.playerTurn,
      status: ZhaJinhuaGameStatus.playing,
      playerCards: pCards,
      opponentCards: oCards,
      playerPeeked: false,
      opponentPeeked: false,
      playerCardsRevealed: false,
      opponentCardsRevealed: false,
      playerChips: playerChips - ZhaJinhuaConstants.anteAmount,
      opponentChips: opponentChips - ZhaJinhuaConstants.anteAmount,
      pot: ZhaJinhuaConstants.anteAmount * 2,
      currentBet: ZhaJinhuaConstants.baseBet,
      roundNumber: 1,
      playerStartChips: playerChips,
      opponentStartChips: opponentChips,
      turnPlayerIndex: 0,
      seed: seed,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
    );
  }

  // ========== 玩家动作 ==========

  /// 看牌/盖牌 (切换).
  void playerPeek() {
    if (!state.isPlayerActionAllowed) return;
    state = state.copyWith(playerPeeked: !state.playerPeeked);
  }

  /// 跟注.
  void playerCall() {
    if (!state.canCall) return;

    final actualPaid = state.playerChips < state.currentBet
        ? state.playerChips
        : state.currentBet;
    final newChips = state.playerChips - actualPaid;
    final newPot = state.pot + actualPaid;

    if (newChips == 0) {
      state = state.copyWith(
        playerChips: 0,
        pot: newPot,
        phase: ZhaJinhuaPhase.showdown,
        playerCardsRevealed: true,
        opponentCardsRevealed: true,
        resultMessage: '全下！',
      );
      _resolveShowdown();
      _notifyAction('call');
      return;
    }

    _switchTurn(ZhaJinhuaPhase.opponentTurn, chipsPaid: actualPaid);
    _notifyAction('call');
  }

  /// 加注.
  void playerRaise() {
    if (!state.canRaise) return;

    final raiseAmount = state.currentBet + ZhaJinhuaConstants.raiseIncrement;
    final actualPaid =
        state.playerChips < raiseAmount ? state.playerChips : raiseAmount;
    final newChips = state.playerChips - actualPaid;
    final newPot = state.pot + actualPaid;
    final isFullRaise = actualPaid >= raiseAmount;
    final newBet = isFullRaise
        ? state.currentBet + ZhaJinhuaConstants.raiseIncrement
        : state.currentBet;

    if (newChips == 0) {
      state = state.copyWith(
        playerChips: 0,
        pot: newPot,
        currentBet: newBet,
        phase: ZhaJinhuaPhase.showdown,
        playerCardsRevealed: true,
        opponentCardsRevealed: true,
        resultMessage: '全下！',
      );
      _resolveShowdown();
      _notifyAction('raise');
      return;
    }

    _switchTurn(ZhaJinhuaPhase.opponentTurn,
        chipsPaid: actualPaid, newBet: newBet);
    _notifyAction('raise');
  }

  /// 弃牌.
  void playerFold() {
    if (!state.isPlayerActionAllowed) return;
    // 底池分配给对手
    state = state.copyWith(
      phase: ZhaJinhuaPhase.roundEnd,
      status: ZhaJinhuaGameStatus.lost,
      opponentChips: state.opponentChips + state.pot,
      pot: 0,
      resultMessage: '你弃牌了',
    );
    _checkGameOver();
    _notifyAction('fold');
  }

  /// 比牌.
  void playerCompare() {
    if (!state.canCompare) return;
    state = state.copyWith(
      phase: ZhaJinhuaPhase.showdown,
      playerCardsRevealed: true,
      opponentCardsRevealed: true,
      resultMessage: '比牌！',
    );
    _resolveShowdown();
    _notifyAction('compare');
  }

  // ========== 对手/AI 动作 ==========

  /// 执行对手动作 (AI 或 PvP handler 调用).
  void executeOpponentAction(AiAction action) {
    // PvP: 校验是否轮到对手操作
    if (!state.isSolo &&
        (state.phase != ZhaJinhuaPhase.opponentTurn ||
            state.turnPlayerIndex != 1)) {
      return;
    }
    switch (action) {
      case AiAction.peek:
        state = state.copyWith(
          opponentPeeked: !state.opponentPeeked,
          phase: state.phase, // 保持原阶段
        );
        break;
      case AiAction.call:
        final actualPaid = state.opponentChips < state.currentBet
            ? state.opponentChips
            : state.currentBet;
        final newChips = state.opponentChips - actualPaid;
        if (newChips == 0) {
          state = state.copyWith(
            opponentChips: 0,
            pot: state.pot + actualPaid,
            phase: ZhaJinhuaPhase.showdown,
            playerCardsRevealed: true,
            opponentCardsRevealed: true,
            resultMessage: '对方全下！',
          );
          _resolveShowdown();
          _notifyAction('opponent_call');
          return;
        }
        _switchTurn(ZhaJinhuaPhase.playerTurn,
            isOpponent: true, chipsPaid: actualPaid);
        break;
      case AiAction.raise:
        final raiseAmount =
            state.currentBet + ZhaJinhuaConstants.raiseIncrement;
        final actualPaid =
            state.opponentChips < raiseAmount ? state.opponentChips : raiseAmount;
        final newChips = state.opponentChips - actualPaid;
        final isFullRaise = actualPaid >= raiseAmount;
        final newBet = isFullRaise
            ? state.currentBet + ZhaJinhuaConstants.raiseIncrement
            : state.currentBet;
        if (newChips == 0) {
          state = state.copyWith(
            opponentChips: 0,
            pot: state.pot + actualPaid,
            currentBet: newBet,
            phase: ZhaJinhuaPhase.showdown,
            playerCardsRevealed: true,
            opponentCardsRevealed: true,
            resultMessage: '对方全下！',
          );
          _resolveShowdown();
          _notifyAction('opponent_raise');
          return;
        }
        _switchTurn(ZhaJinhuaPhase.playerTurn,
            isOpponent: true, chipsPaid: actualPaid, newBet: newBet);
        break;
      case AiAction.fold:
        state = state.copyWith(
          phase: ZhaJinhuaPhase.roundEnd,
          status: ZhaJinhuaGameStatus.won,
          resultMessage: '对手弃牌',
        );
        // 玩家赢得底池
        state = state.copyWith(
          playerChips: state.playerChips + state.pot,
          pot: 0,
        );
        _checkGameOver();
        break;
      case AiAction.compare:
        // Only allow compare when both have bet equally this round
        if (state.playerChipsUsed != state.opponentBet) {
          executeOpponentAction(AiAction.call);
          return;
        }
        state = state.copyWith(
          phase: ZhaJinhuaPhase.showdown,
          playerCardsRevealed: true,
          opponentCardsRevealed: true,
          resultMessage: '对方要求比牌！',
        );
        _resolveShowdown();
        break;
    }
    if (!state.isSolo) _notifyAction('opponent_${action.name}');
  }

  // ========== PvP 接收 Host 结果 ==========

  /// Guest 端应用 Host 发来的动作结果.
  void applyActionResult(Map<String, dynamic> payload) {
    final action = payload['action'] as String;
    final success = payload['success'] as bool? ?? true;
    if (!success) return;

    final playerChips = payload['player_chips'] as int;
    final pot = payload['pot'] as int;
    final currentBet = payload['current_bet'] as int;
    final nextTurn = payload['next_turn'] as int;
    final phase = payload['phase'] as String?;

    Map<String, dynamic> copy = {
      'playerChips': playerChips,
      'pot': pot,
      'currentBet': currentBet,
      'turnPlayerIndex': nextTurn,
      'phase': _parsePhase(phase ?? (nextTurn == 0 ? 'playerTurn' : 'opponentTurn')),
    };

    // 摊牌
    if (payload['result'] != null) {
      final result = payload['result'] as Map<String, dynamic>;
      final winner = result['winner'] as int;
      final pCards = (result['player_cards'] as List)
          .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
          .toList();
      final oCards = (result['opponent_cards'] as List)
          .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
          .toList();
      final playerLabel = result['player_hand_label'] as String?;
      final opponentLabel = result['opponent_hand_label'] as String?;

      // 构造 Guest 视角的结果消息
      String resultMsg;
      if (playerLabel != null && opponentLabel != null) {
        if (winner == 0) {
          resultMsg = '$playerLabel > $opponentLabel，你赢了！';
        } else if (winner == 1) {
          resultMsg = '$opponentLabel > $playerLabel，你输了';
        } else {
          resultMsg = '平局！都是$playerLabel';
        }
      } else {
        resultMsg = winner == 0 ? '你赢了！' : (winner == 1 ? '你输了' : '平局');
      }

      state = state.copyWith(
        playerChips: playerChips,
        opponentChips: payload['opponent_chips'] as int? ?? state.opponentChips,
        pot: pot,
        currentBet: currentBet,
        turnPlayerIndex: nextTurn,
        phase: ZhaJinhuaPhase.roundEnd,
        status: _gameStatusFromWinner(winner),
        playerCards: pCards,
        opponentCards: oCards,
        playerCardsRevealed: true,
        opponentCardsRevealed: true,
        resultMessage: resultMsg,
      );
      _checkGameOver();
      return;
    }

    state = state.copyWith(
      playerChips: playerChips,
      opponentChips: payload['opponent_chips'] as int? ?? state.opponentChips,
      pot: pot,
      currentBet: currentBet,
      turnPlayerIndex: nextTurn,
      phase: copy['phase'] as ZhaJinhuaPhase,
      playerPeeked: payload['has_peeked'] as bool? ?? state.playerPeeked,
    );

    // 如果轮到我们并且是看牌，需要更新已看牌状态
    if (action == 'peek') {
      state = state.copyWith(playerPeeked: payload['has_peeked'] as bool? ?? true);
    }
  }

  ZhaJinhuaPhase _parsePhase(String s) {
    return ZhaJinhuaPhase.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ZhaJinhuaPhase.playerTurn,
    );
  }

  ZhaJinhuaGameStatus _gameStatusFromWinner(int winner) {
    if (winner == 0) return ZhaJinhuaGameStatus.won;
    if (winner == 1) return ZhaJinhuaGameStatus.lost;
    return ZhaJinhuaGameStatus.draw;
  }

  // ========== 摊牌逻辑 ==========

  void _resolveShowdown() {
    final playerEval = HandEvaluation.evaluate(state.playerCards);
    final opponentEval = HandEvaluation.evaluate(state.opponentCards);
    final cmp = playerEval.compareTo(opponentEval);

    final potValue = state.pot;
    String msg;
    ZhaJinhuaGameStatus newStatus;
    int playerChips = state.playerChips;
    int opponentChips = state.opponentChips;

    if (cmp > 0) {
      newStatus = ZhaJinhuaGameStatus.won;
      playerChips += potValue;
      msg = '${playerEval.typeLabel} > ${opponentEval.typeLabel}，你赢了！';
    } else if (cmp < 0) {
      newStatus = ZhaJinhuaGameStatus.lost;
      opponentChips += potValue;
      msg = '${opponentEval.typeLabel} > ${playerEval.typeLabel}，你输了';
    } else {
      newStatus = ZhaJinhuaGameStatus.draw;
      playerChips += potValue ~/ 2;
      opponentChips += potValue - potValue ~/ 2;
      msg = '平局！都是${playerEval.typeLabel}';
    }

    state = state.copyWith(
      phase: ZhaJinhuaPhase.roundEnd,
      status: newStatus,
      playerChips: playerChips,
      opponentChips: opponentChips,
      pot: 0,
      playerCardsRevealed: true,
      opponentCardsRevealed: true,
      resultMessage: msg,
    );

    _checkGameOver();
  }

  // ========== 回合切换 ==========

  /// 通知 PvP 对手状态变更.
  void _notifyAction(String action) {
    if (!state.isSolo && onActionNeeded != null) {
      onActionNeeded!(_buildActionResult(action));
    }
  }

  void _switchTurn(ZhaJinhuaPhase newPhase,
      {bool isOpponent = false,
      int chipsPaid = 0,
      int? newBet}) {
    final update = state.copyWith(
      playerChips: isOpponent
          ? state.playerChips
          : state.playerChips - chipsPaid,
      opponentChips: isOpponent
          ? state.opponentChips - chipsPaid
          : state.opponentChips,
      pot: state.pot + chipsPaid,
      currentBet: newBet ?? state.currentBet,
      turnPlayerIndex: isOpponent ? 0 : 1,
      phase: newPhase,
    );
    state = update;

    // Solo: 轮到 AI
    if (state.isSolo && state.phase == ZhaJinhuaPhase.opponentTurn) {
      _scheduleAiTurn();
    }
  }

  // ========== AI 决策 ==========

  void _scheduleAiTurn() {
    _aiTimer?.cancel();
    final delay = ZhaJinhuaConstants.aiDelayMinMs +
        Random().nextInt(ZhaJinhuaConstants.aiDelayMaxMs -
            ZhaJinhuaConstants.aiDelayMinMs +
            1);
    _aiTimer = Timer(Duration(milliseconds: delay), _executeAiTurn);
  }

  void _executeAiTurn() {
    if (state.phase != ZhaJinhuaPhase.opponentTurn ||
        state.status != ZhaJinhuaGameStatus.playing) {
      return;
    }

    // AI 先看牌 (约 70% 概率看)
    if (!state.opponentPeeked && Random().nextDouble() < 0.7) {
      executeOpponentAction(AiAction.peek);
      // 看牌后继续决策 (用较短的延迟)
      _aiTimer = Timer(
          Duration(milliseconds: ZhaJinhuaConstants.aiDelayMinMs),
          _executeAiTurn);
      return;
    }

    final eval = HandEvaluation.evaluate(state.opponentCards);
    final score = _computeAiScore(eval);

    final action = _aiDecideAction(score);
    executeOpponentAction(action);

    // 如果切换到玩家回合且 Solo 模式下仍在 playing
    if (state.phase == ZhaJinhuaPhase.opponentTurn &&
        state.status == ZhaJinhuaGameStatus.playing) {
      _aiTimer?.cancel();
    }
  }

  double _computeAiScore(HandEvaluation eval) {
    final baseScore = switch (eval.type) {
      HandType.threeOfAKind => 0.95,
      HandType.straightFlush => 0.80,
      HandType.flush => 0.60,
      HandType.straight => 0.40,
      HandType.pair => 0.20,
      HandType.highCard => 0.0,
    };
    // 在同类型内微调
    final rankBonus = eval.compareKey.isNotEmpty
        ? (eval.compareKey[0] - 2) / 12.0 * 0.14
        : 0.0;
    return (baseScore + rankBonus).clamp(0.0, 1.0);
  }

  AiAction _aiDecideAction(double score) {
    final r = Random().nextDouble();
    // 动态调整：筹码少时更激进
    final chipRatio =
        state.opponentChips / ZhaJinhuaConstants.initialChips;
    final aggroBonus = chipRatio < 0.3 ? 0.15 : 0.0;

    if (score >= 0.95) {
      // 豹子: 几乎一定加注
      return r < 0.9 + aggroBonus ? AiAction.raise : AiAction.call;
    } else if (score >= 0.80) {
      if (r < 0.6 + aggroBonus) return AiAction.raise;
      if (r < 0.9) return AiAction.call;
      return AiAction.compare;
    } else if (score >= 0.60) {
      if (r < 0.3 + aggroBonus) return AiAction.raise;
      if (r < 0.8) return AiAction.call;
      return AiAction.compare;
    } else if (score >= 0.40) {
      if (r < 0.1 + aggroBonus) return AiAction.raise;
      if (r < 0.7) return AiAction.call;
      if (r < 0.85) return AiAction.compare;
      return AiAction.fold;
    } else if (score >= 0.20) {
      if (r < 0.05 + aggroBonus) return AiAction.raise;
      if (r < 0.45) return AiAction.call;
      if (r < 0.65) return AiAction.compare;
      return AiAction.fold;
    } else {
      // 散牌: 大概率弃牌
      if (r < 0.25 + aggroBonus) return AiAction.call;
      if (r < 0.40) return AiAction.compare;
      return AiAction.fold;
    }
  }

  // ========== 游戏结束检查 ==========

  /// 检查筹码并为进行下一轮或结束做准备。
  void resolveRoundEnd() {
    if (state.phase == ZhaJinhuaPhase.roundEnd && !state.isGameOver) {
      if (state.playerChips <= 0) {
        state = state.copyWith(
          status: ZhaJinhuaGameStatus.lost,
          resultMessage: '筹码用完了，游戏结束',
        );
      } else if (state.opponentChips <= 0) {
        state = state.copyWith(
          status: ZhaJinhuaGameStatus.won,
          resultMessage: '对手筹码用完了，你赢了！',
        );
      }
      _checkGameOver();
    }
  }

  void _checkGameOver() {
    if (state.status == ZhaJinhuaGameStatus.won ||
        state.status == ZhaJinhuaGameStatus.lost ||
        state.status == ZhaJinhuaGameStatus.draw) {
      if (state.playerChips <= 0) {
        _aiTimer?.cancel();
        state = state.copyWith(
          phase: ZhaJinhuaPhase.gameOver,
          status: ZhaJinhuaGameStatus.lost,
          resultMessage: '筹码用完，游戏结束',
        );
      } else if (state.opponentChips <= 0) {
        _aiTimer?.cancel();
        state = state.copyWith(
          phase: ZhaJinhuaPhase.gameOver,
          status: ZhaJinhuaGameStatus.won,
          resultMessage: '对手筹码用完，你赢了！🎉',
        );
      }
    }
  }

  // ========== 新回合 ==========

  void startNewRound() {
    if (state.playerChips <= ZhaJinhuaConstants.anteAmount ||
        state.opponentChips <= ZhaJinhuaConstants.anteAmount) {
      // 筹码不够下底注 → 游戏结束
      state = state.copyWith(
        status: state.playerChips > state.opponentChips
            ? ZhaJinhuaGameStatus.won
            : ZhaJinhuaGameStatus.lost,
        phase: ZhaJinhuaPhase.gameOver,
        resultMessage: '筹码不够开始新回合',
      );
      _notifyAction('new_round');
      return;
    }

    final newSeed = generateSeed();
    final pCards = Deck.dealHand(newSeed, 0);
    final oCards = Deck.dealHand(newSeed, 1);

    state = ZhaJinhuaState(
      phase: ZhaJinhuaPhase.playerTurn,
      status: ZhaJinhuaGameStatus.playing,
      playerCards: pCards,
      opponentCards: oCards,
      playerPeeked: false,
      opponentPeeked: false,
      playerCardsRevealed: false,
      opponentCardsRevealed: false,
      playerChips: state.playerChips - ZhaJinhuaConstants.anteAmount,
      opponentChips: state.opponentChips - ZhaJinhuaConstants.anteAmount,
      pot: ZhaJinhuaConstants.anteAmount * 2,
      currentBet: ZhaJinhuaConstants.baseBet,
      roundNumber: state.roundNumber + 1,
      playerStartChips: state.playerChips,
      opponentStartChips: state.opponentChips,
      turnPlayerIndex: 0,
      seed: newSeed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
    );

    _notifyAction('new_round');
  }

  /// Guest 端接收新回合开始.
  void applyRoundStart({
    required int seed,
    required List<PlayingCard> playerCards,
    required List<PlayingCard> opponentCards,
    required int playerChips,
    required int opponentChips,
    required int roundNumber,
    required String selfName,
    required String opponentName,
  }) {
    _aiTimer?.cancel();
    state = ZhaJinhuaState(
      phase: ZhaJinhuaPhase.playerTurn,
      status: ZhaJinhuaGameStatus.playing,
      playerCards: playerCards,
      opponentCards: opponentCards,
      playerPeeked: false,
      opponentPeeked: false,
      playerCardsRevealed: false,
      opponentCardsRevealed: false,
      playerChips: playerChips,
      opponentChips: opponentChips,
      pot: ZhaJinhuaConstants.anteAmount * 2,
      currentBet: ZhaJinhuaConstants.baseBet,
      roundNumber: roundNumber,
      playerStartChips: playerChips + ZhaJinhuaConstants.anteAmount,
      opponentStartChips: opponentChips + ZhaJinhuaConstants.anteAmount,
      turnPlayerIndex: 0,
      seed: seed,
      isSolo: false,
      selfName: selfName,
      opponentName: opponentName,
    );
  }

  // ========== PvP: Host 发送动作到 Guest ==========

  /// Host 端: 执行玩家动作并通知 Guest.
  Map<String, dynamic> executeAndNotify(String action) {
    return _executeAction(action);
  }

  Map<String, dynamic> _executeAction(String action) {
    switch (action) {
      case 'peek':
        playerPeek();
        return _buildActionResult('peek');
      case 'call':
        playerCall();
        return _buildActionResult('call');
      case 'raise':
        playerRaise();
        return _buildActionResult('raise');
      case 'fold':
        final prevStatus = state.status;
        playerFold();
        return _buildActionResult('fold', prevStatus: prevStatus);
      case 'compare':
        playerCompare();
        return _buildActionResult('compare');
      default:
        return {};
    }
  }

  Map<String, dynamic> _buildActionResult(String action,
      {ZhaJinhuaGameStatus? prevStatus}) {
    return {
      'action': action,
      'success': true,
      'player_chips': state.playerChips,
      'opponent_chips': state.opponentChips,
      'pot': state.pot,
      'current_bet': state.currentBet,
      'next_turn': state.turnPlayerIndex,
      'has_peeked': state.playerPeeked,
      'phase': state.phase.name,
      'result': state.phase == ZhaJinhuaPhase.roundEnd ||
              state.phase == ZhaJinhuaPhase.gameOver
          ? {
              'winner': state.status == ZhaJinhuaGameStatus.won
                  ? 0
                  : state.status == ZhaJinhuaGameStatus.lost
                      ? 1
                      : -1,
              'player_cards':
                  state.playerCards.map((c) => c.toJson()).toList(),
              'opponent_cards':
                  state.opponentCards.map((c) => c.toJson()).toList(),
              'hand_type': state.resultMessage,
            }
          : null,
    };
  }

  // ========== 断线 / 清理 ==========

  void handleConnectionLost() {
    _aiTimer?.cancel();
    state = state.copyWith(
      status: ZhaJinhuaGameStatus.disconnected,
      resultMessage: '连接已断开',
    );
  }

  void resetGame() {
    _aiTimer?.cancel();
    onActionNeeded = null;
    state = ZhaJinhuaState.initial();
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    super.dispose();
  }
}

// ========== Provider 定义 ==========

final zhaJinhuaStateProvider =
    StateNotifierProvider<ZhaJinhuaStateNotifier, ZhaJinhuaState>((ref) {
  return ZhaJinhuaStateNotifier();
});

final zhaJinhuaRematchStatusProvider =
    StateProvider<ZhaJinhuaRematchStatus>(
        (ref) => ZhaJinhuaRematchStatus.none);

final zhaJinhuaAutoExitProvider = StateProvider<bool>((ref) => false);

final zhaJinhuaToastProvider = StateProvider<String?>((ref) => null);
