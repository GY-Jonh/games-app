/// 坦克大战游戏常量定义。
library;

// ========== 枚举 ==========

/// 地图瓦片类型。
enum TileType {
  empty,
  brick,
  steel,
  water,
  forest,
  ice,
  base,
  baseDestroyed;

  bool get blocksTank =>
      this == brick || this == steel || this == water || this == base;

  bool get blocksBullet => this == brick || this == steel || this == base;

  bool get isDestructible => this == brick;
}

/// 方向。
enum Direction {
  up,
  right,
  down,
  left;

  int get dx => switch (this) {
        Direction.left => -1,
        Direction.right => 1,
        _ => 0,
      };

  int get dy => switch (this) {
        Direction.up => -1,
        Direction.down => 1,
        _ => 0,
      };

  Direction get opposite => switch (this) {
        Direction.up => Direction.down,
        Direction.down => Direction.up,
        Direction.left => Direction.right,
        Direction.right => Direction.left,
      };

  static Direction fromIndex(int i) => Direction.values[i % 4];
}

/// 坦克类型。
enum TankType {
  player1,
  player2,
  enemyBasic,
  enemyFast,
  enemyArmor,
  enemyHeavy;

  bool get isPlayer => this == player1 || this == player2;

  bool get isEnemy => !isPlayer;

  int get maxHp => switch (this) {
        TankType.enemyArmor => 2,
        TankType.enemyHeavy => 4,
        _ => 1,
      };

  int get baseSpeed => switch (this) {
        TankType.enemyFast => 5,
        TankType.player1 || TankType.player2 => 4,
        _ => 3,
      };

  int get scoreValue => switch (this) {
        TankType.enemyFast => 200,
        TankType.enemyArmor => 300,
        TankType.enemyHeavy => 400,
        _ => 100,
      };
}

/// 游戏阶段。
enum TankBattlePhase {
  loading,
  levelIntro,
  playing,
  levelComplete,
  won,
  lost,
  disconnected;
}

// ========== 数值常量 ==========

class TankBattleConstants {
  TankBattleConstants._();

  static const int gridSize = 20;
  static const int ticksPerSecond = 60;
  static const double tickDuration = 1.0 / ticksPerSecond; // ~0.0167s

  // 坦克
  static const double tankHitboxSize = 0.9;
  static const double gridSnapThreshold = 0.025;
  static const int shootCooldownTicks = 30; // ~0.5s
  static const int spawnInvincibleTicks = 90; // 1.5 秒

  // 子弹
  static const int bulletSpeed = 10; // 瓦片/秒
  static const double bulletHitboxSize = 0.25;

  // 生成
  static const int spawnIntervalTicks = 180; // 3 秒
  static const int maxEnemiesOnField = 4;
  static const int initialLives = 3;
  static const int maxLives = 5;

  // 关卡
  static const int totalMaps = 5;
  static const int levelCompleteDelayTicks = 180; // 3 秒
  static const int levelIntroDelayTicks = 120; // 2 秒

  // PvP 同步
  static const int syncIntervalTicks = 9; // 每 9 帧同步一次 (~150ms)

  // 爆炸动画
  static const int explosionDurationTicks = 24; // ~0.4s

  // 计分
  static const int levelCompleteBonus = 1000;
}

// ========== 生成点 ==========

class SpawnPoints {
  SpawnPoints._();

  // 玩家出生点 (row, col) — 基地两侧
  static const List<(int, int)> player = [(18, 8), (18, 12)];

  // 敌人出生点 — 地图顶部
  static const List<(int, int)> enemy = [(0, 0), (0, 9), (0, 19)];
}

// ========== 地图数据 ==========

class TankBattleMaps {
  TankBattleMaps._();

  /// 获取指定关卡的地图 (1-indexed)，循环使用。
  static List<String> getMap(int level) {
    final index = (level - 1) % _maps.length;
    return _maps[index];
  }

  static final List<List<String>> _maps = [
    // 关卡 1: 训练场 — 开阔，少量砖墙
    [
      '....................',
      '....................',
      '..BB..BB..BB..BB..BB',
      '..BB..BB..BB..BB..BB',
      '..BB..BB..BB..BB..BB',
      '..BB..BB..BB..BB..BB',
      '..BB..BBSSBB..BB..BB',
      '..BB..BB..BB..BB..BB',
      '......BB..BB........',
      '......BB..BB........',
      'BB..BB........BB..BB',
      'BB..BB........BB..BB',
      '..BB..BB..BB..BB..BB',
      '..BB..BB..BB..BB..BB',
      '..BB..BB..BB..BB..BB',
      '..BB..BB..BB..BB..BB',
      '....................',
      '....................',
      '........BBBB........',
      '........BEEB........',
    ],
    // 关卡 2: 堡垒 — 大量砖墙，部分钢墙
    [
      '....................',
      '....................',
      'BBSSBBBBBBSSBBBBSSBB',
      'BB..BB..BB..BB..BB.B',
      '....BB..BB..BB..BB..',
      'BB..BBBBBBBBBB..BB..',
      'BB..BB......BB..BB..',
      'BBBBBB.SSSS.BBBBBB..',
      '......SS..SS........',
      'BB..BB......BB..BB..',
      'BB..BBBBBB..BB..BB..',
      '....BB..BB..BB......',
      'SS..BB..BB..BB..SS..',
      '....BBBBBBBBBBBB....',
      'BB..BB......BB..BB..',
      'BB..BB..SS..BB..BB..',
      '......BB..BB........',
      '......BB..BB........',
      '........BBBB........',
      '........BEEB........',
    ],
    // 关卡 3: 渡河 — 水道分割地图
    [
      '....................',
      '....................',
      '..BB..BB..BB..BB..BB',
      '..BB..BB..BB..BB..BB',
      'WWWWWWWW..WWWWWWWWWW',
      '..BB..BB..BB..BB....',
      '..BB..BB..BB..BB..BB',
      '....WWWW..WWWW......',
      '..BB......BB..BB..BB',
      '..BB..WWWWBB..BB..BB',
      '......WWWW..........',
      '..BB..BB..BB..BB..BB',
      '..BB..BB..BB..BB..BB',
      'WWWW..WWWWWWWW..WWWW',
      '..BB..BB..BB..BB....',
      '..BB..BB..BB..BB..BB',
      '......BB..BB........',
      '......BB..BB........',
      '........BBBB........',
      '........BEEB........',
    ],
    // 关卡 4: 丛林伏击 — 密集森林
    [
      '....................',
      '....................',
      'FFBBFFBBFFBBFFBBFFBB',
      'FFBBFFBBFFBBFFBBFFBB',
      '..BB..FF..FF..BB....',
      '..BB..FF..FF..BB..BB',
      'FFFFFFBB..BBFFFFFFFF',
      '..BB..BB..BB..BB....',
      '..BB......BB..BB..BB',
      'FFFF..BBBBBB..FFFFFF',
      '..BB..BB..BB..BB....',
      '..BB..BB..BB..BB..BB',
      'FFFFFF..FF..FFFFFFFF',
      '..BB..FF..FF..BB....',
      '..BB..FF..FF..BB..BB',
      '..BBBB..BB..BBBB..BB',
      '......BB..BB........',
      '......BB..BB........',
      '........BBBB........',
      '........BEEB........',
    ],
    // 关卡 5: 冰霜堡垒 — 钢墙+冰面
    [
      '....................',
      '....................',
      '..SS..II..II..SS..SS',
      '..SS..II..II..SS..SS',
      '..BB..BBSSBB..BB..BB',
      '..BB..BB..BB..BB..BB',
      'IIII..BB..BB..IIIIII',
      '..BB..BBBBBB..BB....',
      '..BBIIII..IIIIBB..BB',
      '..BB..BB..BB..BB..BB',
      'SS..SSBBBBBBSS..SS..',
      '..BB..BB..BB..BB....',
      '..BB..BB..BB..BB..BB',
      'IIII..SS..SS..IIIIII',
      '..BB..BB..BB..BB....',
      '..BB..BBSSBB..BB..BB',
      '..SS..BB..BB..SS....',
      '......BB..BB........',
      '........BBBB........',
      '........BEEB........',
    ],
  ];
}
