/// 点灯游戏的常量定义
class LightsOutConstants {
  /// 网格大小（5×5）
  static const int gridSize = 5;

  /// 网格总格子数
  static const int totalCells = gridSize * gridSize;

  /// 游戏倒计时（秒）
  static const int roundTimeSeconds = 300;

  /// 棋盘生成时随机点击的次数
  static const int minMovesToGenerate = 12;
  static const int maxMovesToGenerate = 18;
}
