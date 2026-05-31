/// 炸金花不可变游戏状态。
library;

import 'package:gomoku_app/features/zha_jinhua/constants/zha_jinhua_constants.dart';
import 'package:gomoku_app/features/zha_jinhua/models/playing_card.dart';

class ZhaJinhuaState {
  final ZhaJinhuaPhase phase;
  final ZhaJinhuaGameStatus status;

  // 手牌
  final List<PlayingCard> playerCards;
  final List<PlayingCard> opponentCards;
  final bool playerPeeked;
  final bool opponentPeeked;
  final bool playerCardsRevealed;
  final bool opponentCardsRevealed;

  // 筹码
  final int playerChips;
  final int opponentChips;
  final int pot;
  final int currentBet;
  final int roundNumber;

  // 本轮开始时双方的筹码（用于计算本轮下注额）
  final int playerStartChips;
  final int opponentStartChips;

  // 回合控制
  final int turnPlayerIndex; // 0=玩家, 1=对手/AI
  final int seed; // 用于 PvP 同步
  final bool isSolo;
  final String selfName;
  final String opponentName;

  final String? resultMessage;

  const ZhaJinhuaState({
    required this.phase,
    required this.status,
    required this.playerCards,
    required this.opponentCards,
    required this.playerPeeked,
    required this.opponentPeeked,
    required this.playerCardsRevealed,
    required this.opponentCardsRevealed,
    required this.playerChips,
    required this.opponentChips,
    required this.pot,
    required this.currentBet,
    required this.roundNumber,
    required this.playerStartChips,
    required this.opponentStartChips,
    required this.turnPlayerIndex,
    required this.seed,
    required this.isSolo,
    required this.selfName,
    required this.opponentName,
    this.resultMessage,
  });

  factory ZhaJinhuaState.initial() => ZhaJinhuaState(
        phase: ZhaJinhuaPhase.playerTurn,
        status: ZhaJinhuaGameStatus.loading,
        playerCards: const [],
        opponentCards: const [],
        playerPeeked: false,
        opponentPeeked: false,
        playerCardsRevealed: false,
        opponentCardsRevealed: false,
        playerChips: ZhaJinhuaConstants.initialChips,
        opponentChips: ZhaJinhuaConstants.initialChips,
        pot: 0,
        currentBet: ZhaJinhuaConstants.baseBet,
        roundNumber: 1,
        turnPlayerIndex: 0,
        playerStartChips: ZhaJinhuaConstants.initialChips,
        opponentStartChips: ZhaJinhuaConstants.initialChips,
        seed: 0,
        isSolo: true,
        selfName: '',
        opponentName: '',
      );

  // ========== 辅助 Getter ==========

  bool get isPlayerActionAllowed =>
      phase == ZhaJinhuaPhase.playerTurn &&
      status == ZhaJinhuaGameStatus.playing;

  bool get canCall =>
      isPlayerActionAllowed && playerChips > 0; // 允许任何正数筹码（含 All-in）

  bool get canAllIn =>
      isPlayerActionAllowed &&
      playerChips > 0 &&
      playerChips < currentBet; // 筹码不足当前注时为 All-in

  bool get canRaise =>
      isPlayerActionAllowed &&
      playerChips >= currentBet + ZhaJinhuaConstants.raiseIncrement;

  bool get canCompare =>
      isPlayerActionAllowed &&
      playerChipsUsed == opponentBet; // 双方本轮下注相等才能比牌

  int get opponentBet => opponentStartChips - opponentChips;

  int get playerChipsUsed => playerStartChips - playerChips;

  bool get isGameOver =>
      status == ZhaJinhuaGameStatus.won ||
      status == ZhaJinhuaGameStatus.lost ||
      status == ZhaJinhuaGameStatus.draw ||
      status == ZhaJinhuaGameStatus.disconnected;

  // ========== copyWith ==========

  ZhaJinhuaState copyWith({
    ZhaJinhuaPhase? phase,
    ZhaJinhuaGameStatus? status,
    List<PlayingCard>? playerCards,
    List<PlayingCard>? opponentCards,
    bool? playerPeeked,
    bool? opponentPeeked,
    bool? playerCardsRevealed,
    bool? opponentCardsRevealed,
    int? playerChips,
    int? opponentChips,
    int? pot,
    int? currentBet,
    int? roundNumber,
    int? playerStartChips,
    int? opponentStartChips,
    int? turnPlayerIndex,
    int? seed,
    bool? isSolo,
    String? selfName,
    String? opponentName,
    String? resultMessage,
    bool clearResultMessage = false,
  }) =>
      ZhaJinhuaState(
        phase: phase ?? this.phase,
        status: status ?? this.status,
        playerCards: playerCards ?? this.playerCards,
        opponentCards: opponentCards ?? this.opponentCards,
        playerPeeked: playerPeeked ?? this.playerPeeked,
        opponentPeeked: opponentPeeked ?? this.opponentPeeked,
        playerCardsRevealed:
            playerCardsRevealed ?? this.playerCardsRevealed,
        opponentCardsRevealed:
            opponentCardsRevealed ?? this.opponentCardsRevealed,
        playerChips: playerChips ?? this.playerChips,
        opponentChips: opponentChips ?? this.opponentChips,
        pot: pot ?? this.pot,
        currentBet: currentBet ?? this.currentBet,
        roundNumber: roundNumber ?? this.roundNumber,
        playerStartChips: playerStartChips ?? this.playerStartChips,
        opponentStartChips:
            opponentStartChips ?? this.opponentStartChips,
        turnPlayerIndex: turnPlayerIndex ?? this.turnPlayerIndex,
        seed: seed ?? this.seed,
        isSolo: isSolo ?? this.isSolo,
        selfName: selfName ?? this.selfName,
        opponentName: opponentName ?? this.opponentName,
        resultMessage:
            clearResultMessage ? null : (resultMessage ?? this.resultMessage),
      );
}
