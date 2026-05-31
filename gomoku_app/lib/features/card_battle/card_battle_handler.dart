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
    // Guest 更新本地的引擎状态
    final phaseStr = payload['phase'] as String?;
    if (phaseStr != null) {
      ref.read(cardBattleStateProvider.notifier).applyRemoteState(
            CardBattleState.fromJson(payload),
          );
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

    ref.read(cardBattleStateProvider.notifier).applyRoundStart(
          seed: seed,
          playerCards: pCards,
          opponentCards: oCards,
          selfName: deviceName,
          opponentName: opponentName,
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
    final state = ref.read(cardBattleStateProvider);
    if (state.status != CardBattleStatus.playing &&
        !state.isGameOver) return;

    final payload = state.toJson();
    // 翻转视角: player ↔ opponent
    payload['phase'] = _flipPhase(state.phase.name);
    payload['opponent_name'] = deviceName;

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

  /// 翻转阶段名 (playerTurn ↔ opponentTurn).
  String _flipPhase(String phase) {
    if (phase == 'playerTurn') return 'opponentTurn';
    if (phase == 'opponentTurn') return 'playerTurn';
    return phase;
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
