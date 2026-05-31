/// 炸金花游戏常量。
library;

// ========== 枚举 ==========

/// 游戏阶段。
enum ZhaJinhuaPhase {
  playerTurn, // 等待我方操作
  opponentTurn, // 等待对方操作
  showdown, // 摊牌中
  roundEnd, // 回合结束
  gameOver, // 游戏结束
}

/// 游戏状态。
enum ZhaJinhuaGameStatus {
  loading,
  playing,
  won,
  lost,
  draw,
  disconnected,
}

// ========== 数值常量 ==========

class ZhaJinhuaConstants {
  ZhaJinhuaConstants._();

  static const int initialChips = 100;
  static const int anteAmount = 5;
  static const int baseBet = 10;
  static const int raiseIncrement = 10;
  static const int cardsPerPlayer = 3;
  static const int totalCards = 52;
  static const int aiDelayMinMs = 800;
  static const int aiDelayMaxMs = 1500;
}
