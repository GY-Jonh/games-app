/// 2048 游戏的常量定义
class Game2048Constants {
  /// 网格大小（5×5）
  static const int gridSize = 5;

  /// 总格子数
  static const int totalCells = gridSize * gridSize;

  /// 获胜目标值
  static const int winValue = 2048;

  /// 游戏倒计时（秒）
  static const int roundTimeSeconds = 600;

  /// 新方块为 4 的概率（10%）
  static const double spawnFourProbability = 0.1;
}
