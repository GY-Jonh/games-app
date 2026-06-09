/// 扑克收集战 — GameHandler 实现。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/game_framework/game_handler.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/card_battle/card_battle_providers.dart';
import 'package:gomoku_app/features/card_battle/constants/card_battle_constants.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_card.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_state.dart';
import 'package:gomoku_app/features/card_battle/card_battle_screen.dart';
import 'package:gomoku_app/models/network_message.dart';

class CardBattleHandler extends GameHandler {
  final WidgetRef ref;
  final void Function(NetworkMessage) _sendMessage;
  int _myPlayerIndex = 0;
  bool _isSolo = false;

  CardBattleHandler(this.ref, this._sendMessage);

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
    } else {
      _setupAsGuest();
    }
  }

  void _startSoloGame() {
    final seed = CardBattleStateNotifier.generateSeed();
    ref.read(cardBattleStateProvider.notifier).startGame(
          seed: seed,
          isSolo: true,
          selfName: deviceName,
        );
  }

  void _startPvPAsHost() {
    final seed = CardBattleStateNotifier.generateSeed();
    final notifier = ref.read(cardBattleStateProvider.notifier);

    // 状态变更通知
    notifier.onActionNeeded = (actionMap) {
      _sendActionResult(actionMap);
    };

    notifier.startGame(
      seed: seed,
      isSolo: false,
      selfName: deviceName,
      opponentName: '',
    );

    // Host 重赛：直接重启 engine 并通知 Guest
    notifier.onRematch = _restartGame;

    // 发送初始状态给 Guest
    _sendRoundStart();
  }

  void _setupAsGuest() {
    final notifier = ref.read(cardBattleStateProvider.notifier);
    // Guest 操作时发送消息给 Host
    notifier.onGuestActionNeeded = (String action, List<Map<String, dynamic>>? cards) {
      final payload = <String, dynamic>{'action': action};
      if (cards != null) {
        payload['cards'] = cards;
      }
      _sendMessage(NetworkMessage(
        type: 'card_battle_action',
        senderId: deviceId,
        payload: payload,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    };

    // Guest 重赛：发送重赛请求给 Host
    notifier.onRematch = () {
      _sendMessage(NetworkMessage(
        type: 'card_battle_rematch_request',
        senderId: deviceId,
        payload: {},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    };
  }

  // ========== 消息处理 ==========

  @override
  void handleMessage(NetworkMessage message) {
    switch (message.type) {
      case 'card_battle_action':
        _handleGuestAction(message);
        break;
      case 'card_battle_action_result':
        _handleActionResult(message);
        break;
      case 'card_battle_round_start':
        _handleRoundStart(message);
        break;
      case 'card_battle_game_over':
        _handleGameOver(message);
        break;
      case 'card_battle_rematch_request':
        _handleRematchRequest(message);
        break;
      case 'card_battle_rematch_response':
        _handleRematchResponse(message);
        break;
    }
  }

  /// Host 处理 Guest 的操作请求.
  void _handleGuestAction(NetworkMessage message) {
    final action = message.payload['action'] as String;
    final notifier = ref.read(cardBattleStateProvider.notifier);

    if (action == 'pass') {
      notifier.opponentPass();
    } else if (action == 'play') {
      final cards = (message.payload['cards'] as List)
          .map((c) => GameCard.fromJson(c as Map<String, dynamic>))
          .toList();
      notifier.opponentPlay(cards);
    }
    // onActionNeeded 回调会自动发结果给 Guest
  }

  /// Guest 接收 Host 发来的动作结果或回合更新.
  void _handleActionResult(NetworkMessage message) {
    final payload = message.payload;
    if (payload.containsKey('phase') && payload['phase'] != null) {
      try {
        ref.read(cardBattleStateProvider.notifier).applyRemoteState(
              CardBattleState.fromJson(payload),
            );
      } catch (e) {
        // 防止反序列化异常导致整个消息管道中断
      }
    }
  }

  /// Guest 接收 Host 发来的回合开始.
  void _handleRoundStart(NetworkMessage message) {
    final payload = message.payload;
    final seed = payload['seed'] as int;
    final pCards = (payload['player_cards'] as List)
        .map((c) => GameCard.fromJson(c as Map<String, dynamic>))
        .toList();
    final oCards = (payload['opponent_cards'] as List)
        .map((c) => GameCard.fromJson(c as Map<String, dynamic>))
        .toList();
    final opponentName =
        payload['opponent_name'] as String? ?? '对手';
    final turnPlayerIndex = payload['turn_player_index'] as int? ?? 0;

    ref.read(cardBattleStateProvider.notifier).applyRoundStart(
          seed: seed,
          playerCards: pCards,
          opponentCards: oCards,
          selfName: deviceName,
          opponentName: opponentName,
          turnPlayerIndex: turnPlayerIndex,
        );
  }

  void _handleGameOver(NetworkMessage message) {
    final reason = message.payload['reason'] as String? ?? 'unknown';
    if (reason == 'quit' || reason == 'disconnect') {
      ref.read(cardBattleStateProvider.notifier).handleConnectionLost();
    }
  }

  // ========== 网络发送 ==========

  /// 发送动作结果或状态更新给 Guest (翻转视角).
  void _sendActionResult(Map<String, dynamic> actionMap) {
    final s = ref.read(cardBattleStateProvider);
    if (s.status != CardBattleStatus.playing && !s.isGameOver) return;

    // 手动构建 JSON，同时翻转 Host→Guest 视角
    final payload = <String, dynamic>{
      'phase': (s.phase == CardBattlePhase.playerTurn
              ? CardBattlePhase.opponentTurn
              : CardBattlePhase.playerTurn)
          .index,
      'status': s.status.index,
      // 翻转手牌：Guest 的手 = Host 的对手
      'player_hand':
          s.opponentHand.map((c) => c.toJson()).toList(),
      'opponent_hand':
          s.playerHand.map((c) => c.toJson()).toList(),
      // 桌面牌（已拆分为双方）
      'table_cards':
          s.tableCards.map((c) => c.toJson()).toList(),
      'player_table_cards':
          s.opponentTableCards.map((c) => c.toJson()).toList(),
      'opponent_table_cards':
          s.playerTableCards.map((c) => c.toJson()).toList(),
      // 收集牌
      'player_collected':
          s.opponentCollected.map((c) => c.toJson()).toList(),
      'opponent_collected':
          s.playerCollected.map((c) => c.toJson()).toList(),
      // 数值
      'deck_remaining': s.deckRemaining,
      'current_combo_type': s.currentCombo?.type.index,
      'current_combo_value': s.currentCombo?.primaryValue,
      'current_combo_length': s.currentCombo?.length,
      'first_player': s.firstPlayer == 0 ? 1 : 0,
      'turn_player_index': s.turnPlayerIndex == 0 ? 1 : 0,
      'round_number': s.roundNumber,
      'last_round_passed': s.lastRoundPassed ? 1 : 0,
      'last_play_was_pass': s.lastPlayWasPass ? 1 : 0,
      'player_hand_count': s.opponentHandCount,
      'opponent_hand_count': s.playerHandCount,
      'result_message': s.resultMessage,
      'opponent_name': deviceName,
      'self_name': '',
    };

    _sendMessage(NetworkMessage(
      type: 'card_battle_action_result',
      senderId: deviceId,
      payload: payload,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// 发送新回合给 Guest.
  void _sendRoundStart() {
    final state = ref.read(cardBattleStateProvider);
    if (state.status != CardBattleStatus.playing) return;

    _sendMessage(NetworkMessage(
      type: 'card_battle_round_start',
      senderId: deviceId,
      payload: {
        'seed': state.seed,
        'player_cards':
            state.opponentHand.map((c) => c.toJson()).toList(),
        'opponent_cards':
            state.playerHand.map((c) => c.toJson()).toList(),
        'player_collected':
            state.opponentCollected.map((c) => c.toJson()).toList(),
        'opponent_collected':
            state.playerCollected.map((c) => c.toJson()).toList(),
        'deck_remaining': state.deckRemaining,
        'first_player': state.firstPlayer == 0 ? 1 : 0,
        'turn_player_index': state.turnPlayerIndex == 0 ? 1 : 0,
        'round_number': state.roundNumber,
        'opponent_name': deviceName,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  // ========== 断线 / 重赛 ==========

  @override
  void handleConnectionLost() {
    final gameState = ref.read(cardBattleStateProvider);
    if (gameState.status == CardBattleStatus.playing) {
      ref.read(cardBattleStateProvider.notifier).handleConnectionLost();
    }
  }

  void _handleRematchRequest(NetworkMessage message) {
    final gameState = ref.read(cardBattleStateProvider);
    if (gameState.status == CardBattleStatus.playing) return;

    // 自动同意重赛
    _sendMessage(NetworkMessage(
      type: 'card_battle_rematch_response',
      senderId: deviceId,
      payload: {'accepted': true},
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    _restartGame();
  }

  void _handleRematchResponse(NetworkMessage message) {
    final accepted = message.payload['accepted'] as bool? ?? false;
    if (accepted) {
      _restartGame();
    }
  }

  void _restartGame() {
    if (_isSolo) {
      _startSoloGame();
    } else if (_myPlayerIndex == 0) {
      _startPvPAsHost();
    }
  }

  // ========== 生命周期 ==========

  @override
  Widget buildScreen({
    required String opponentName,
    required void Function(NetworkMessage) onSendMessage,
  }) {
    return CardBattleScreen(
      opponentName: opponentName,
      onSendMessage: onSendMessage,
    );
  }

  @override
  void dispose() {
    ref.read(cardBattleStateProvider.notifier).resetGame();
  }
}
