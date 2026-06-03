/// 炸金花处理器，实现 GameHandler 接口。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/game_framework/game_handler.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/zha_jinhua/constants/zha_jinhua_constants.dart';
import 'package:gomoku_app/features/zha_jinhua/models/playing_card.dart';
import 'package:gomoku_app/features/zha_jinhua/zha_jinhua_providers.dart';
import 'package:gomoku_app/features/zha_jinhua/zha_jinhua_screen.dart';
import 'package:gomoku_app/models/network_message.dart';

class ZhaJinhuaHandler extends GameHandler {
  final WidgetRef ref;
  final void Function(NetworkMessage) _sendMessage;
  int _myPlayerIndex = 0;
  bool _isSolo = false;

  ZhaJinhuaHandler(this.ref, this._sendMessage);

  @override
  void initGame({
    required int myPlayerIndex,
    required String opponentName,
  }) {
    _myPlayerIndex = myPlayerIndex;
    _isSolo = opponentName.isEmpty;

    if (_isSolo) {
      _startSoloGame();
    } else if (_myPlayerIndex == 0) {
      _startPvPAsHost();
    }
    // Guest 等待 zha_jinhua_round_start
  }

  void _startSoloGame() {
    final seed = ZhaJinhuaStateNotifier.generateSeed();
    ref.read(zhaJinhuaStateProvider.notifier).startGame(
          seed: seed,
          isSolo: true,
          selfName: deviceName,
        );
  }

  void _startPvPAsHost() {
    final seed = ZhaJinhuaStateNotifier.generateSeed();
    final notifier = ref.read(zhaJinhuaStateProvider.notifier);

    // 设置通知回调: 状态变更时发送给 Guest
    notifier.onActionNeeded = (actionMap) {
      final action = actionMap['action'] as String;
      if (action == 'new_round') {
        _sendRoundStart();
      } else {
        _sendActionResult(action);
      }
    };

    // 发牌
    final allCards = Deck.shuffleDeck(seed);
    final hostCards = [allCards[0], allCards[1], allCards[2]];
    final guestCards = [allCards[3], allCards[4], allCards[5]];

    notifier.startGame(
      seed: seed,
      isSolo: false,
      selfName: deviceName,
      playerCards: hostCards,
      opponentCards: guestCards,
    );

    // 发送回合开始给 Guest (已翻转视角)
    _sendMessage(NetworkMessage(
      type: 'zha_jinhua_round_start',
      senderId: deviceId,
      payload: {
        'seed': seed,
        'player_cards': guestCards.map((c) => c.toJson()).toList(),
        'opponent_cards': hostCards.map((c) => c.toJson()).toList(),
        'player_chips':
            ZhaJinhuaConstants.initialChips - ZhaJinhuaConstants.anteAmount,
        'opponent_chips':
            ZhaJinhuaConstants.initialChips - ZhaJinhuaConstants.anteAmount,
        'pot': ZhaJinhuaConstants.anteAmount * 2,
        'current_bet': ZhaJinhuaConstants.baseBet,
        'round_number': 1,
        'opponent_name': deviceName,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  // ========== 消息处理 ==========

  @override
  void handleMessage(NetworkMessage message) {
    switch (message.type) {
      case 'zha_jinhua_player_action':
        _handleGuestAction(message);
        break;
      case 'zha_jinhua_action_result':
        _handleActionResult(message);
        break;
      case 'zha_jinhua_round_start':
        _handleRoundStart(message);
        break;
      case 'zha_jinhua_game_over':
        _handleGameOver(message);
        break;
      case 'zha_jinhua_rematch_request':
        _handleRematchRequest(message);
        break;
      case 'zha_jinhua_rematch_response':
        _handleRematchResponse(message);
        break;
    }
  }

  /// Host 处理 Guest 的操作请求.
  void _handleGuestAction(NetworkMessage message) {
    final action = message.payload['action'] as String;
    final notifier = ref.read(zhaJinhuaStateProvider.notifier);

    switch (action) {
      case 'peek':
        notifier.executeOpponentAction(AiAction.peek);
        break;
      case 'call':
        notifier.executeOpponentAction(AiAction.call);
        break;
      case 'raise':
        notifier.executeOpponentAction(AiAction.raise);
        break;
      case 'fold':
        notifier.executeOpponentAction(AiAction.fold);
        break;
      case 'compare':
        notifier.executeOpponentAction(AiAction.compare);
        break;
    }
    // onActionNeeded 回调会自动发送结果给 Guest
  }

  /// Guest 接收 Host 发来的动作结果.
  void _handleActionResult(NetworkMessage message) {
    ref.read(zhaJinhuaStateProvider.notifier).applyActionResult(
          Map<String, dynamic>.from(message.payload),
        );
  }

  /// Guest 接收 Host 发来的回合开始.
  void _handleRoundStart(NetworkMessage message) {
    final payload = message.payload;
    final pCards = (payload['player_cards'] as List)
        .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
        .toList();
    final oCards = (payload['opponent_cards'] as List)
        .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
        .toList();
    final roundNumber = payload['round_number'] as int? ?? 1;
    final opponentName =
        payload['opponent_name'] as String? ?? '对手';

    ref.read(zhaJinhuaStateProvider.notifier).applyRoundStart(
          seed: payload['seed'] as int,
          playerCards: pCards,
          opponentCards: oCards,
          playerChips: payload['player_chips'] as int,
          opponentChips: payload['opponent_chips'] as int,
          roundNumber: roundNumber,
          selfName: deviceName,
          opponentName: opponentName,
        );
  }

  void _handleGameOver(NetworkMessage message) {
    final reason = message.payload['reason'] as String? ?? 'unknown';
    if (reason == 'chip_out') {
      final winner = message.payload['winner'] as int? ?? -1;
      ref.read(zhaJinhuaStateProvider.notifier).handleChipOut(winner);
    } else if (reason == 'quit' || reason == 'disconnect') {
      ref.read(zhaJinhuaStateProvider.notifier).handleConnectionLost();
    }
  }

  // ========== 网络发送 ==========

  /// 发送动作结果给 Guest (翻转视角).
  void _sendActionResult(String action) {
    final state = ref.read(zhaJinhuaStateProvider);

    final payload = <String, dynamic>{
      'action': action,
      'success': true,
      'player_chips': state.opponentChips,
      'opponent_chips': state.playerChips,
      'pot': state.pot,
      'current_bet': state.currentBet,
      'next_turn': state.turnPlayerIndex == 0 ? 1 : 0,
      'has_peeked': state.opponentPeeked,
      'phase': _flipPhase(state.phase.name),
    };

    // 包含摊牌/回合结束结果
    if (state.phase == ZhaJinhuaPhase.roundEnd ||
        state.phase == ZhaJinhuaPhase.gameOver) {
      final winner = state.status == ZhaJinhuaGameStatus.won
          ? 0
          : state.status == ZhaJinhuaGameStatus.lost
              ? 1
              : -1;
      // 评估双方手牌类型，发送标签而非 Host 视角消息
      final playerEval = HandEvaluation.evaluate(state.opponentCards);
      final opponentEval = HandEvaluation.evaluate(state.playerCards);
      payload['result'] = {
        'winner': winner == 0 ? 1 : (winner == 1 ? 0 : -1),
        'player_cards':
            state.opponentCards.map((c) => c.toJson()).toList(),
        'opponent_cards':
            state.playerCards.map((c) => c.toJson()).toList(),
        'player_hand_label': playerEval.typeLabel,
        'opponent_hand_label': opponentEval.typeLabel,
      };
    }

    _sendMessage(NetworkMessage(
      type: 'zha_jinhua_action_result',
      senderId: deviceId,
      payload: payload,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// 发送新回合给 Guest.
  void _sendRoundStart() {
    final state = ref.read(zhaJinhuaStateProvider);
    if (state.status != ZhaJinhuaGameStatus.playing) {
      // 筹码不足等非 playing 状态 → 通知 Guest 游戏结束
      _sendMessage(NetworkMessage(
        type: 'zha_jinhua_game_over',
        senderId: deviceId,
        payload: {
          'reason': 'chip_out',
          'winner': state.playerChips > state.opponentChips ? 0 : 1,
        },
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      return;
    }

    _sendMessage(NetworkMessage(
      type: 'zha_jinhua_round_start',
      senderId: deviceId,
      payload: {
        'seed': state.seed,
        'player_cards':
            state.opponentCards.map((c) => c.toJson()).toList(),
        'opponent_cards':
            state.playerCards.map((c) => c.toJson()).toList(),
        'player_chips': state.opponentChips,
        'opponent_chips': state.playerChips,
        'pot': state.pot,
        'current_bet': state.currentBet,
        'round_number': state.roundNumber,
        'opponent_name': deviceName,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// 翻转阶段名 (playerTurn ↔ opponentTurn).
  String _flipPhase(String phase) {
    if (phase == 'playerTurn') return 'opponentTurn';
    if (phase == 'opponentTurn') return 'playerTurn';
    return phase;
  }

  // ========== 断线 / 重赛 ==========

  @override
  void handleConnectionLost() {
    ref.read(zhaJinhuaRematchStatusProvider.notifier).state =
        ZhaJinhuaRematchStatus.none;

    final gameState = ref.read(zhaJinhuaStateProvider);
    if (gameState.status == ZhaJinhuaGameStatus.playing) {
      ref.read(zhaJinhuaStateProvider.notifier).handleConnectionLost();
    } else {
      ref.read(zhaJinhuaAutoExitProvider.notifier).state = true;
    }
  }

  void _handleRematchRequest(NetworkMessage message) {
    final gameState = ref.read(zhaJinhuaStateProvider);
    if (gameState.status == ZhaJinhuaGameStatus.playing) return;

    if (ref.read(zhaJinhuaRematchStatusProvider) ==
        ZhaJinhuaRematchStatus.waiting) {
      // 双方同时请求，自动同意
      _sendMessage(NetworkMessage(
        type: 'zha_jinhua_rematch_response',
        senderId: deviceId,
        payload: {'accepted': true},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      _restartGame();
    } else {
      ref.read(zhaJinhuaRematchStatusProvider.notifier).state =
          ZhaJinhuaRematchStatus.received;
      ref.read(zhaJinhuaToastProvider.notifier).state = '对方请求了重赛';
    }
  }

  void _handleRematchResponse(NetworkMessage message) {
    final accepted = message.payload['accepted'] as bool? ?? false;
    if (accepted) {
      _restartGame();
    } else {
      ref.read(zhaJinhuaRematchStatusProvider.notifier).state =
          ZhaJinhuaRematchStatus.none;
      ref.read(zhaJinhuaToastProvider.notifier).state = '对方拒绝了重赛请求';
    }
  }

  void _restartGame() {
    ref.read(zhaJinhuaRematchStatusProvider.notifier).state =
        ZhaJinhuaRematchStatus.none;

    if (_isSolo) {
      _startSoloGame();
    } else if (_myPlayerIndex == 0) {
      _startPvPAsHost();
    }
    // Guest 等待 Host 发送 zha_jinhua_round_start
  }

  // ========== 生命周期 ==========

  @override
  Widget buildScreen({
    required String opponentName,
    required void Function(NetworkMessage) onSendMessage,
  }) {
    return ZhaJinhuaScreen(
      opponentName: opponentName,
      onSendMessage: onSendMessage,
      myPlayerIndex: _myPlayerIndex,
    );
  }

  @override
  void dispose() {
    ref.read(zhaJinhuaStateProvider.notifier).resetGame();
    ref.read(zhaJinhuaRematchStatusProvider.notifier).state =
        ZhaJinhuaRematchStatus.none;
    ref.read(zhaJinhuaAutoExitProvider.notifier).state = false;
    ref.read(zhaJinhuaToastProvider.notifier).state = null;
  }
}
