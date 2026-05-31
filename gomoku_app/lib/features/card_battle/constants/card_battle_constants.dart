/// 扑克收集战 — 常量与枚举。
library;

// ========== 牌型枚举 ==========

/// 牌型。
enum ComboType {
  single,
  pair,
  straight,
  bomb,
  jokerBomb,
}

/// 游戏阶段。
enum CardBattlePhase {
  playerTurn, // 等待我方出牌
  opponentTurn, // 等待对方出牌
  roundEnd, // 回合结束（收牌阶段）
  gameOver, // 游戏结束
}

/// 游戏状态。
enum CardBattleStatus {
  loading,
  playing,
  won,
  lost,
  disconnected,
}

// ========== 数值常量 ==========

class CardBattleConstants {
  CardBattleConstants._();

  static const int handSize = 5; // 每人手牌数
  static const int totalCards = 54; // 54张（含大小王）
  static const int regularCards = 52; // 52张常规牌

  // 点数比较值映射：3→3, 4→4, ..., K→13, A→14, 2→15, 小王→16, 大王→17
  static const int minRank = 3;
  static const int maxRank = 14; // A
  static const int rank2Value = 15;
  static const int smallJokerValue = 16;
  static const int bigJokerValue = 17;

  static const int minStraightLen = 3; // 最短顺子
  static const int maxStraightLen = 12; // 3-A 共12张
  static const int minBombLen = 3; // 最少3张才算炸弹

  // AI
  static const int aiDelayMinMs = 800;
  static const int aiDelayMaxMs = 1500;
}
