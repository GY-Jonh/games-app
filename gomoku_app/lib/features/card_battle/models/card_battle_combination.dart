/// 扑克收集战 — 牌型组合检测与比较。
library;

import 'package:gomoku_app/features/card_battle/constants/card_battle_constants.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_card.dart';

/// 一组牌的牌型分析结果。
class CardCombo {
  final ComboType type;
  final List<GameCard> cards;
  final int primaryValue; // 主比较值
  final int length; // 张数

  const CardCombo({
    required this.type,
    required this.cards,
    required this.primaryValue,
    required this.length,
  });

  /// 判断本组合是否能管上 [other]。
  bool canBeat(CardCombo other) {
    // 王炸最大
    if (type == ComboType.jokerBomb) return true;
    if (other.type == ComboType.jokerBomb) return false;

    // 炸弹可以炸非炸弹
    if (type == ComboType.bomb && other.type != ComboType.bomb) return true;
    if (type != ComboType.bomb && other.type == ComboType.bomb) return false;

    // 不同类型不能管（炸弹已经单独处理过）
    if (type != other.type) return false;

    // 同类型比大小
    switch (type) {
      case ComboType.single:
      case ComboType.pair:
        return primaryValue > other.primaryValue;
      case ComboType.straight:
        // 顺子必须长度相同才能比
        if (length != other.length) return false;
        return primaryValue > other.primaryValue;
      case ComboType.bomb:
        // 炸弹：张数多 > 张数少；同张数比点数
        if (length != other.length) return length > other.length;
        return primaryValue > other.primaryValue;
      case ComboType.jokerBomb:
        return true; // unreachable
    }
  }

  /// 简要描述。
  String get label {
    switch (type) {
      case ComboType.single:
        return cards.first.displayLabel;
      case ComboType.pair:
        return '对子 ${cards.first.rankLabel}';
      case ComboType.straight:
        final top = cards.last.rankLabel;
        return '顺子 $length张 顶$top';
      case ComboType.bomb:
        return '炸弹 ${cards.first.rankLabel} ×$length';
      case ComboType.jokerBomb:
        return '王炸';
    }
  }
}

// ========== 牌型检测 ==========

class ComboDetector {
  ComboDetector._();

  /// 检测选中的牌是否构成有效牌型。
  /// 返回 null 表示无效。
  static CardCombo? detect(List<GameCard> cards) {
    if (cards.isEmpty) return null;
    final n = cards.length;

    // 检查王炸（2张王牌）
    if (n == 2) {
      final hasSmall = cards.any((c) => c.isSmallJoker);
      final hasBig = cards.any((c) => c.isBigJoker);
      if (hasSmall && hasBig) {
        return CardCombo(
          type: ComboType.jokerBomb,
          cards: List.from(cards),
          primaryValue: 99,
          length: 2,
        );
      }
    }

    // 炸弹（3+张同点数）
    if (n >= CardBattleConstants.minBombLen) {
      final firstRank = cards.first.rank;
      if (!cards.first.isJoker && cards.every((c) => c.rank == firstRank)) {
        return CardCombo(
          type: ComboType.bomb,
          cards: List.from(cards),
          primaryValue: cards.first.compareValue,
          length: n,
        );
      }
    }

    // 单张
    if (n == 1) {
      return CardCombo(
        type: ComboType.single,
        cards: List.from(cards),
        primaryValue: cards.first.compareValue,
        length: 1,
      );
    }

    // 对子（2张同点数，不含王牌）
    if (n == 2) {
      if (!cards[0].isJoker &&
          !cards[1].isJoker &&
          cards[0].rank == cards[1].rank) {
        return CardCombo(
          type: ComboType.pair,
          cards: List.from(cards),
          primaryValue: cards[0].compareValue,
          length: 2,
        );
      }
      return null; // 非同点两张无效
    }

    // 顺子（3+张连续点数）
    if (n >= CardBattleConstants.minStraightLen) {
      // 按点数排序
      final sorted = List<GameCard>.from(cards)
        ..sort((a, b) => a.compareValue.compareTo(b.compareValue));
      // 检查不含2和王
      if (sorted.any((c) => c.isJoker || c.rank == 2)) return null;
      // 检查是否连续
      bool isConsecutive = true;
      for (int i = 1; i < sorted.length; i++) {
        if (sorted[i].compareValue != sorted[i - 1].compareValue + 1) {
          isConsecutive = false;
          break;
        }
      }
      if (isConsecutive) {
        return CardCombo(
          type: ComboType.straight,
          cards: sorted,
          primaryValue: sorted.last.compareValue,
          length: n,
        );
      }
    }

    return null; // 无效
  }

  /// 从手牌中找出所有能管上 [current] 的牌型组合，
  /// 按"代价"排序（代价 = 牌张数，炸弹/王炸额外加权重）。
  static List<CardCombo> findBeatingCombos(
    List<GameCard> hand,
    CardCombo current,
  ) {
    final results = <CardCombo>[];

    // 1. 如果能出王炸
    final jokerCards = hand.where((c) => c.isJoker).toList();
    if (jokerCards.length >= 2) {
      results.add(CardCombo(
        type: ComboType.jokerBomb,
        cards: jokerCards,
        primaryValue: 99,
        length: 2,
      ));
    }

    // 2. 炸弹（3+张同点数）
    final rankGroups = <int, List<GameCard>>{};
    for (final card in hand) {
      if (!card.isJoker) {
        rankGroups.putIfAbsent(card.rank, () => []).add(card);
      }
    }
    for (final group in rankGroups.values) {
      if (group.length >= CardBattleConstants.minBombLen) {
        final combo = CardCombo(
          type: ComboType.bomb,
          cards: List.from(group),
          primaryValue: group.first.compareValue,
          length: group.length,
        );
        if (combo.canBeat(current)) {
          results.add(combo);
        }
      }
    }

    // 3. 如果对方出的是非炸弹，尝试同类型管上
    if (current.type != ComboType.bomb &&
        current.type != ComboType.jokerBomb) {
      switch (current.type) {
        case ComboType.single:
          for (final card in hand) {
            if (card.compareValue > current.primaryValue) {
              results.add(CardCombo(
                type: ComboType.single,
                cards: [card],
                primaryValue: card.compareValue,
                length: 1,
              ));
            }
          }
          break;

        case ComboType.pair:
          for (final group in rankGroups.values) {
            if (group.length >= 2 &&
                group.first.compareValue > current.primaryValue) {
              results.add(CardCombo(
                type: ComboType.pair,
                cards: group.take(2).toList(),
                primaryValue: group.first.compareValue,
                length: 2,
              ));
            }
          }
          break;

        case ComboType.straight:
          results.addAll(findStraights(hand, current.length)
              .where((s) => s.canBeat(current)));
          break;

        default:
          break;
      }
    }

    // 按代价排序（优先出代价最小的）
    results.sort((a, b) => _comboCost(a).compareTo(_comboCost(b)));

    return results;
  }

  /// 找所有指定长度的顺子。
  static List<CardCombo> findStraights(List<GameCard> hand, int length) {
    final results = <CardCombo>[];
    // 提取可用于顺子的牌（不含2和王，去重按点数）
    final usable = hand
        .where((c) => !c.isJoker && c.rank != 2)
        .map((c) => c.rank)
        .toSet()
        .toList()
      ..sort();
    if (usable.length < length) return results;

    for (int i = 0; i <= usable.length - length; i++) {
      bool isConsecutive = true;
      for (int j = 1; j < length; j++) {
        if (usable[i + j] != usable[i + j - 1] + 1) {
          isConsecutive = false;
          break;
        }
      }
      if (isConsecutive) {
        final comboCards = <GameCard>[];
        for (int k = 0; k < length; k++) {
          final rank = usable[i + k];
          comboCards.add(hand.firstWhere((c) => c.rank == rank));
        }
        final topRank = comboCards.last.compareValue;
        results.add(CardCombo(
          type: ComboType.straight,
          cards: comboCards,
          primaryValue: topRank,
          length: length,
        ));
      }
    }
    return results;
  }

  /// 组合的"代价"分数（越小越优先出）。
  static int _comboCost(CardCombo combo) {
    switch (combo.type) {
      case ComboType.single:
        return combo.primaryValue;
      case ComboType.pair:
        return 100 + combo.primaryValue;
      case ComboType.straight:
        return 200 + combo.length * 10 + combo.primaryValue;
      case ComboType.bomb:
        return 500 + (combo.length - 3) * 100 + combo.primaryValue;
      case ComboType.jokerBomb:
        return 999;
    }
  }
}
