/// 记忆翻牌的常量定义
class MemoryMatchConstants {
  /// 网格列数
  static const int gridColumns = 4;

  /// 网格行数
  static const int gridRows = 4;

  /// 总卡片数
  static const int totalCards = gridColumns * gridRows;

  /// 配对数
  static const int pairCount = totalCards ~/ 2;

  /// 游戏倒计时（秒）
  static const int roundTimeSeconds = 300;

  /// 翻牌后展示延迟（毫秒），之后自动翻转回去或保持匹配
  static const int revealDelayMs = 800;

  /// 卡面对应的 8 种不同图案
  static const List<String> cardSymbols = [
    '🌸', '🌻', '🍀', '🎈',
    '🍭', '🎸', '🐱', '🦋',
  ];
}
