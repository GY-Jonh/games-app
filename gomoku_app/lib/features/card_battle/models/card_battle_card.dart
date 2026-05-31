/// 扑克收集战 — 扑克牌模型（含大小王）。
library;

import 'dart:math';
import 'package:gomoku_app/features/card_battle/constants/card_battle_constants.dart';

/// 一张扑克牌。
class GameCard {
  final int suit; // 0=♠ 1=♥ 2=♣ 3=♦
  final int rank; // 3-14（3-10=数字, 11=J, 12=Q, 13=K, 14=A）, 0=joker
  final bool isJoker;
  final int jokerType; // 0=小王, 1=大王

  const GameCard({
    required this.suit,
    required this.rank,
    this.isJoker = false,
    this.jokerType = 0,
  });

  /// 创建小丑牌。
  const GameCard.smallJoker()
      : suit = -1,
        rank = 0,
        isJoker = true,
        jokerType = 0;

  /// 创建大王牌。
  const GameCard.bigJoker()
      : suit = -1,
        rank = 0,
        isJoker = true,
        jokerType = 1;

  bool get isSmallJoker => isJoker && jokerType == 0;
  bool get isBigJoker => isJoker && jokerType == 1;

  /// 比较用数值：3→3 … A→14, 2→15, 小王→16, 大王→17。
  int get compareValue {
    if (isSmallJoker) return CardBattleConstants.smallJokerValue;
    if (isBigJoker) return CardBattleConstants.bigJokerValue;
    if (rank == 2) return CardBattleConstants.rank2Value;
    return rank;
  }

  /// 显示标签（用于调试和UI）。
  String get displayLabel {
    if (isSmallJoker) return '小王';
    if (isBigJoker) return '大王';
    const suits = ['♠', '♥', '♣', '♦'];
    const ranks = [
      '', '', '', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A',
    ];
    return '${suits[suit]}${ranks[rank]}';
  }

  String get suitSymbol {
    if (isJoker) return '';
    const symbols = ['♠', '♥', '♣', '♦'];
    return symbols[suit];
  }

  String get rankLabel {
    if (isSmallJoker) return '小';
    if (isBigJoker) return '大';
    const labels = [
      '', '', '', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A',
    ];
    return labels[rank];
  }

  @override
  String toString() => displayLabel;

  @override
  bool operator ==(Object other) =>
      other is GameCard &&
      suit == other.suit &&
      rank == other.rank &&
      isJoker == other.isJoker &&
      jokerType == other.jokerType;

  @override
  int get hashCode => Object.hash(suit, rank, isJoker, jokerType);

  Map<String, dynamic> toJson() => {
        's': suit,
        'r': rank,
        'j': isJoker ? 1 : 0,
        'jt': jokerType,
      };

  factory GameCard.fromJson(Map<String, dynamic> json) {
    final isJoker = (json['j'] as int?) == 1;
    if (isJoker) {
      return json['jt'] == 0 ? GameCard.smallJoker() : GameCard.bigJoker();
    }
    return GameCard(
      suit: json['s'] as int,
      rank: json['r'] as int,
    );
  }
}

// ========== 牌组 ==========

class GameDeck {
  GameDeck._();

  /// 创建54张完整牌组。
  static List<GameCard> createDeck() {
    final cards = <GameCard>[];
    for (int suit = 0; suit < 4; suit++) {
      for (int rank = 3; rank <= 14; rank++) {
        cards.add(GameCard(suit: suit, rank: rank));
      }
    }
    // 加2（点数2在3-A之后）
    for (int suit = 0; suit < 4; suit++) {
      cards.add(GameCard(suit: suit, rank: 2));
    }
    cards.add(const GameCard.smallJoker());
    cards.add(const GameCard.bigJoker());
    return cards;
  }

  /// 洗牌并返回。
  static List<GameCard> shuffleDeck(int seed) {
    final random = Random(seed);
    final cards = createDeck();
    for (int i = cards.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = cards[i];
      cards[i] = cards[j];
      cards[j] = temp;
    }
    return cards;
  }

  /// 从牌堆发 n 张牌（返回发走的牌和剩余牌堆）。
  static (List<GameCard>, List<GameCard>) dealCards(
    List<GameCard> deck,
    int count,
  ) {
    final dealt = deck.take(count).toList();
    final remaining = deck.skip(count).toList();
    return (dealt, remaining);
  }
}
