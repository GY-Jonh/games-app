/// 扑克牌模型：PlayingCard、HandEvaluation、Deck。
library;

import 'dart:math';

// ========== PlayingCard ==========

/// 一张扑克牌。
class PlayingCard {
  final int suit; // 0=♠ 1=♥ 2=♣ 3=♦
  final int rank; // 2-14 (11=J, 12=Q, 13=K, 14=A)

  const PlayingCard({required this.suit, required this.rank});

  String get suitSymbol => switch (suit) {
        0 => '♠',
        1 => '♥',
        2 => '♣',
        3 => '♦',
        _ => '?',
      };

  String get rankLabel => switch (rank) {
        14 => 'A',
        13 => 'K',
        12 => 'Q',
        11 => 'J',
        _ => rank.toString(),
      };

  String get displayLabel => '$suitSymbol$rankLabel';

  Map<String, dynamic> toJson() => {'s': suit, 'r': rank};

  factory PlayingCard.fromJson(Map<String, dynamic> json) => PlayingCard(
        suit: json['s'] as int,
        rank: json['r'] as int,
      );

  @override
  String toString() => displayLabel;

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && suit == other.suit && rank == other.rank;

  @override
  int get hashCode => suit * 13 + rank;
}

// ========== HandType ==========

/// 炸金花牌型。
enum HandType {
  highCard, // 散牌
  pair, // 对子
  straight, // 顺子
  flush, // 金花
  straightFlush, // 同花顺
  threeOfAKind, // 豹子
}

// ========== HandEvaluation ==========

/// 3 张牌的手牌评估结果。
class HandEvaluation {
  final HandType type;
  final List<int> compareKey; // 字典序比较键

  const HandEvaluation({required this.type, required this.compareKey});

  /// 评估 3 张牌，返回排序后的 [HandEvaluation]。
  static HandEvaluation evaluate(List<PlayingCard> cards) {
    if (cards.length != 3) {
      return const HandEvaluation(
          type: HandType.highCard, compareKey: [0, 0, 0]);
    }

    // 按 rank 升序排序
    final sorted = List<PlayingCard>.from(cards)..sort((a, b) => a.rank - b.rank);
    final r0 = sorted[0].rank;
    final r1 = sorted[1].rank;
    final r2 = sorted[2].rank;
    final sameSuit = sorted.every((c) => c.suit == sorted[0].suit);

    // 判断顺子
    bool isStraight = false;
    if (r0 + 1 == r1 && r1 + 1 == r2) {
      isStraight = true;
    } else if (r0 == 2 && r1 == 3 && r2 == 14) {
      // A-2-3: 特殊顺子 (最小)
      isStraight = true;
    }

    // 判断豹子 (三条)
    final isTriple = r0 == r1 && r1 == r2;

    if (isTriple) {
      return HandEvaluation(
        type: HandType.threeOfAKind,
        compareKey: [r2, r1, r0],
      );
    }

    if (sameSuit && isStraight) {
      // 同花顺: A-K-Q > K-Q-J > ... > A-2-3
      if (r0 == 2 && r1 == 3 && r2 == 14) {
        // A-2-3 最小顺子
        return const HandEvaluation(
          type: HandType.straightFlush,
          compareKey: [3, 2, 1],
        );
      }
      return HandEvaluation(
        type: HandType.straightFlush,
        compareKey: [r2, r1, r0],
      );
    }

    if (sameSuit) {
      return HandEvaluation(
        type: HandType.flush,
        compareKey: [r2, r1, r0],
      );
    }

    if (isStraight) {
      if (r0 == 2 && r1 == 3 && r2 == 14) {
        return const HandEvaluation(
          type: HandType.straight,
          compareKey: [3, 2, 1],
        );
      }
      return HandEvaluation(
        type: HandType.straight,
        compareKey: [r2, r1, r0],
      );
    }

    // 对子: 两牌相同
    if (r0 == r1) {
      return HandEvaluation(
        type: HandType.pair,
        compareKey: [r0, r2],
      );
    }
    if (r1 == r2) {
      return HandEvaluation(
        type: HandType.pair,
        compareKey: [r1, r0],
      );
    }

    // 散牌
    return HandEvaluation(
      type: HandType.highCard,
      compareKey: [r2, r1, r0],
    );
  }

  /// (-1)=小于, 0=等于, 1=大于。
  int compareTo(HandEvaluation other) {
    if (type.index != other.type.index) {
      return type.index.compareTo(other.type.index);
    }
    final length = compareKey.length;
    for (int i = 0; i < length; i++) {
      if (compareKey[i] != other.compareKey[i]) {
        return compareKey[i].compareTo(other.compareKey[i]);
      }
    }
    return 0;
  }

  /// 中文牌型名。
  String get typeLabel => switch (type) {
        HandType.threeOfAKind => '豹子',
        HandType.straightFlush => '同花顺',
        HandType.flush => '金花',
        HandType.straight => '顺子',
        HandType.pair => '对子',
        HandType.highCard => '散牌',
      };

  @override
  String toString() => '$typeLabel ${compareKey.join(",")}';
}

// ========== Deck ==========

class Deck {
  Deck._();

  /// 生成 52 张有序的牌。
  static List<PlayingCard> createDeck() {
    final cards = <PlayingCard>[];
    for (int suit = 0; suit < 4; suit++) {
      for (int rank = 2; rank <= 14; rank++) {
        cards.add(PlayingCard(suit: suit, rank: rank));
      }
    }
    return cards;
  }

  /// 用种子洗牌并返回 [totalCards] 张。
  static List<PlayingCard> shuffleDeck(int seed, {int totalCards = 52}) {
    final random = Random(seed);
    final cards = createDeck();
    // Fisher-Yates 洗牌
    for (int i = cards.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = cards[i];
      cards[i] = cards[j];
      cards[j] = temp;
    }
    return cards.sublist(0, totalCards);
  }

  /// 从种子洗牌后的牌堆中给 [playerIndex] (0/1) 发 3 张牌。
  static List<PlayingCard> dealHand(int seed, int playerIndex) {
    final cards = shuffleDeck(seed);
    final start = playerIndex * 3;
    return [cards[start], cards[start + 1], cards[start + 2]];
  }
}
