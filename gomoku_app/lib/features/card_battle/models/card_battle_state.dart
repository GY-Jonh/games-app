/// 扑克收集战 — 游戏状态。
library;

import 'package:gomoku_app/features/card_battle/constants/card_battle_constants.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_card.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_combination.dart';

/// 游戏状态（不可变）。
class CardBattleState {
  final CardBattlePhase phase;
  final CardBattleStatus status;

  // 牌堆
  final List<GameCard> deck;

  // 手牌
  final List<GameCard> playerHand;
  final List<GameCard> opponentHand;

  // 本轮桌面上已出的牌（谁出的 + 出的什么）
  final List<GameCard> tableCards;
  final List<GameCard> playerTableCards;
  final List<GameCard> opponentTableCards;
  final CardCombo? currentCombo; // 当前打出的牌型
  final bool lastPlayWasPass; // 上一手是否是"过"

  // 收集的牌
  final List<GameCard> playerCollected;
  final List<GameCard> opponentCollected;

  // 谁先手（0=玩家, 1=对手）
  final int firstPlayer;
  final int turnPlayerIndex; // 当前轮到谁

  // 游戏信息
  final int seed;
  final bool isSolo;
  final String selfName;
  final String opponentName;
  final String? resultMessage;

  // PvP 跟踪
  final int roundNumber;
  final bool lastRoundPassed; // 上轮是否有人"过"（用于收牌判断）

  const CardBattleState({
    required this.phase,
    required this.status,
    required this.deck,
    required this.playerHand,
    required this.opponentHand,
    required this.tableCards,
    required this.playerTableCards,
    required this.opponentTableCards,
    this.currentCombo,
    required this.lastPlayWasPass,
    required this.playerCollected,
    required this.opponentCollected,
    required this.firstPlayer,
    required this.turnPlayerIndex,
    required this.seed,
    required this.isSolo,
    required this.selfName,
    required this.opponentName,
    this.resultMessage,
    required this.roundNumber,
    required this.lastRoundPassed,
  });

  factory CardBattleState.initial() => CardBattleState(
        phase: CardBattlePhase.playerTurn,
        status: CardBattleStatus.loading,
        deck: [],
        playerHand: [],
        opponentHand: [],
        tableCards: [],
        playerTableCards: [],
        opponentTableCards: [],
        lastPlayWasPass: false,
        playerCollected: [],
        opponentCollected: [],
        firstPlayer: 0,
        turnPlayerIndex: 0,
        seed: 0,
        isSolo: true,
        selfName: '',
        opponentName: '',
        roundNumber: 0,
        lastRoundPassed: false,
      );

  // ========== 统计 ==========

  int get playerCollectedCount => playerCollected.length;
  int get opponentCollectedCount => opponentCollected.length;
  int get deckRemaining => deck.length;

  int get playerHandCount => playerHand.length;
  int get opponentHandCount => opponentHand.length;

  bool get isGameOver =>
      status == CardBattleStatus.won ||
      status == CardBattleStatus.lost ||
      status == CardBattleStatus.draw ||
      status == CardBattleStatus.disconnected;

  bool get isPlayerTurn =>
      phase == CardBattlePhase.playerTurn &&
      status == CardBattleStatus.playing;

  bool get isOpponentTurn =>
      phase == CardBattlePhase.opponentTurn &&
      status == CardBattleStatus.playing;

  bool get canPass =>
      (phase == CardBattlePhase.playerTurn ||
              phase == CardBattlePhase.opponentTurn) &&
      status == CardBattleStatus.playing &&
      tableCards.isNotEmpty; // 桌上有牌才能过

  // ========== copyWith ==========

  CardBattleState copyWith({
    CardBattlePhase? phase,
    CardBattleStatus? status,
    List<GameCard>? deck,
    List<GameCard>? playerHand,
    List<GameCard>? opponentHand,
    List<GameCard>? tableCards,
    List<GameCard>? playerTableCards,
    List<GameCard>? opponentTableCards,
    CardCombo? currentCombo,
    bool clearCurrentCombo = false,
    bool? lastPlayWasPass,
    List<GameCard>? playerCollected,
    List<GameCard>? opponentCollected,
    int? firstPlayer,
    int? turnPlayerIndex,
    int? seed,
    bool? isSolo,
    String? selfName,
    String? opponentName,
    String? resultMessage,
    bool clearResultMessage = false,
    int? roundNumber,
    bool? lastRoundPassed,
  }) =>
      CardBattleState(
        phase: phase ?? this.phase,
        status: status ?? this.status,
        deck: deck ?? this.deck,
        playerHand: playerHand ?? this.playerHand,
        opponentHand: opponentHand ?? this.opponentHand,
        tableCards: tableCards ?? this.tableCards,
        playerTableCards: playerTableCards ?? this.playerTableCards,
        opponentTableCards: opponentTableCards ?? this.opponentTableCards,
        currentCombo: clearCurrentCombo ? null : (currentCombo ?? this.currentCombo),
        lastPlayWasPass: lastPlayWasPass ?? this.lastPlayWasPass,
        playerCollected: playerCollected ?? this.playerCollected,
        opponentCollected: opponentCollected ?? this.opponentCollected,
        firstPlayer: firstPlayer ?? this.firstPlayer,
        turnPlayerIndex: turnPlayerIndex ?? this.turnPlayerIndex,
        seed: seed ?? this.seed,
        isSolo: isSolo ?? this.isSolo,
        selfName: selfName ?? this.selfName,
        opponentName: opponentName ?? this.opponentName,
        resultMessage:
            clearResultMessage ? null : (resultMessage ?? this.resultMessage),
        roundNumber: roundNumber ?? this.roundNumber,
        lastRoundPassed: lastRoundPassed ?? this.lastRoundPassed,
      );

  // ========== 序列化（PvP 同步用） ==========

  Map<String, dynamic> toJson() => {
        'phase': phase.index,
        'status': status.index,
        'player_hand': playerHand.map((c) => c.toJson()).toList(),
        'opponent_hand': opponentHand.map((c) => c.toJson()).toList(),
        'table_cards': tableCards.map((c) => c.toJson()).toList(),
        'player_table_cards': playerTableCards.map((c) => c.toJson()).toList(),
        'opponent_table_cards': opponentTableCards.map((c) => c.toJson()).toList(),
        'player_collected': playerCollected.map((c) => c.toJson()).toList(),
        'opponent_collected': opponentCollected.map((c) => c.toJson()).toList(),
        'deck_remaining': deckRemaining,
        'current_combo_type': currentCombo?.type.index,
        'current_combo_value': currentCombo?.primaryValue,
        'current_combo_length': currentCombo?.length,
        'first_player': firstPlayer,
        'turn_player_index': turnPlayerIndex,
        'round_number': roundNumber,
        'last_round_passed': lastRoundPassed ? 1 : 0,
        'player_hand_count': playerHandCount,
        'opponent_hand_count': opponentHandCount,
        'result_message': resultMessage,
        'self_name': selfName,
        'opponent_name': opponentName,
      };

  factory CardBattleState.fromJson(Map<String, dynamic> json) {
    final res = json['result_message'] as String?;
    return CardBattleState(
      phase: CardBattlePhase.values[json['phase'] as int],
      status: CardBattleStatus.values[json['status'] as int],
      deck: [],
      playerHand: (json['player_hand'] as List)
          .map((c) => GameCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      opponentHand: (json['opponent_hand'] as List)
          .map((c) => GameCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      tableCards: (json['table_cards'] as List)
          .map((c) => GameCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      playerTableCards: (json['player_table_cards'] as List?)
              ?.map((c) => GameCard.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      opponentTableCards: (json['opponent_table_cards'] as List?)
              ?.map((c) => GameCard.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      lastPlayWasPass: false,
      playerCollected: (json['player_collected'] as List)
          .map((c) => GameCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      opponentCollected: (json['opponent_collected'] as List)
          .map((c) => GameCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      firstPlayer: json['first_player'] as int,
      turnPlayerIndex: json['turn_player_index'] as int,
      seed: 0,
      isSolo: false,
      selfName: json['self_name'] as String? ?? '',
      opponentName: json['opponent_name'] as String? ?? '',
      resultMessage: res,
      roundNumber: json['round_number'] as int? ?? 1,
      lastRoundPassed: (json['last_round_passed'] as int?) == 1,
    );
  }
}
