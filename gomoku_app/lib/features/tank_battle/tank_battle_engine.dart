/// 坦克大战游戏引擎 — 纯 Dart，无 Flutter 依赖。
library;

import 'dart:math';
import 'package:gomoku_app/features/tank_battle/constants/tank_battle_constants.dart';
import 'package:gomoku_app/features/tank_battle/models/tank_battle_state.dart';

/// 引擎内部坦克实体 (可变)。
class _Tank {
  int id;
  double x;
  double y;
  Direction direction;
  TankType type;
  int hp;
  bool isAlive;
  int shootCooldown;
  int invincibleFrames;
  int ownerPlayerIndex; // 0/1 玩家, -1 敌人
  bool isMoving;
  int stuckTicks;

  _Tank({
    required this.id,
    required this.x,
    required this.y,
    required this.direction,
    required this.type,
    required this.hp,
    required this.ownerPlayerIndex,
  })  : isAlive = true,
        shootCooldown = 0,
        invincibleFrames = TankBattleConstants.spawnInvincibleTicks,
        isMoving = false,
        stuckTicks = 0;
}

/// 引擎内部子弹实体 (可变)。
class _Bullet {
  int id;
  double x;
  double y;
  Direction direction;
  int ownerId;
  int ownerPlayerIndex;
  bool isActive;

  _Bullet({
    required this.id,
    required this.x,
    required this.y,
    required this.direction,
    required this.ownerId,
    required this.ownerPlayerIndex,
  }) : isActive = true;
}

/// 引擎内部爆炸效果。
class _Explosion {
  double x;
  double y;
  int frame;
  bool isLarge;

  _Explosion({
    required this.x,
    required this.y,
    required this.frame,
    this.isLarge = false,
  });
}

class TankBattleEngine {
  final int level;
  final int seed;
  final int playerCount;
  late final Random _random;

  // 地图
  late List<List<TileType>> _map;
  (int, int)? _basePos;

  // 实体
  final List<_Tank> _tanks = [];
  final List<_Bullet> _bullets = [];
  final List<_Explosion> _explosions = [];

  // ID 计数器
  int _nextTankId = 0;
  int _nextBulletId = 0;

  // 游戏状态
  int _tickCount = 0;
  int _score = 0;
  int _livesRemaining;
  final int _totalEnemies;
  int _spawnedEnemies = 0;
  int _spawnTimer = 0;
  bool _isBaseDestroyed = false;
  bool _isLevelComplete = false;
  bool _isGameOver = false;

  // 玩家输入缓冲
  final Map<int, (Direction?, bool)> _playerInputs = {};

  TankBattleEngine({
    required this.level,
    required this.seed,
    this.playerCount = 1,
  })  : _livesRemaining = TankBattleConstants.initialLives,
        _totalEnemies = _calcTotalEnemies(level) {
    _random = Random(seed);
    _initMap();
    _spawnPlayerTanks();
  }

  static int _calcTotalEnemies(int level) =>
      min(10 + level * 2, 20);

  // ========== 初始化 ==========

  void _initMap() {
    final mapData = TankBattleMaps.getMap(level);
    _map = List.generate(
      TankBattleConstants.gridSize,
      (row) => List.generate(TankBattleConstants.gridSize, (col) {
        final ch = mapData[row][col];
        return switch (ch) {
          'B' => TileType.brick,
          'S' => TileType.steel,
          'W' => TileType.water,
          'F' => TileType.forest,
          'I' => TileType.ice,
          'E' => TileType.base,
          _ => TileType.empty,
        };
      }),
    );
    // 找到基地位置
    for (int r = 0; r < TankBattleConstants.gridSize; r++) {
      for (int c = 0; c < TankBattleConstants.gridSize; c++) {
        if (_map[r][c] == TileType.base) {
          _basePos = (r, c);
          return;
        }
      }
    }
  }

  void _spawnPlayerTanks() {
    for (int i = 0; i < playerCount; i++) {
      final (row, col) = SpawnPoints.player[i % SpawnPoints.player.length];
      // 清除出生点周围的障碍
      _clearSpawnArea(row, col);
      _tanks.add(_Tank(
        id: _nextTankId++,
        x: col.toDouble(),
        y: row.toDouble(),
        direction: Direction.up,
        type: i == 0 ? TankType.player1 : TankType.player2,
        hp: 1,
        ownerPlayerIndex: i,
      ));
    }
  }

  void _clearSpawnArea(int row, int col) {
    for (int dr = -1; dr <= 0; dr++) {
      for (int dc = -1; dc <= 0; dc++) {
        final r = row + dr;
        final c = col + dc;
        if (r >= 0 &&
            r < TankBattleConstants.gridSize &&
            c >= 0 &&
            c < TankBattleConstants.gridSize) {
          if (_map[r][c] == TileType.brick || _map[r][c] == TileType.steel) {
            _map[r][c] = TileType.empty;
          }
        }
      }
    }
  }

  // ========== 公共接口 ==========

  void setPlayerInput(int playerIndex, Direction? direction, bool firing) {
    _playerInputs[playerIndex] = (direction, firing);
  }

  void tick(double deltaTime) {
    if (_isLevelComplete || _isGameOver) return;
    _tickCount++;

    _processInputs(deltaTime);
    _updateAI();
    _moveTanks(deltaTime);
    _moveBullets(deltaTime);
    _checkCollisions();
    _manageSpawns();
    _checkWinLose();
    _cleanup();
  }

  bool get isLevelComplete => _isLevelComplete;
  bool get isGameOver => _isGameOver;
  int get score => _score;
  int get livesRemaining => _livesRemaining;
  int get enemiesRemaining => _totalEnemies - _spawnedEnemies + _aliveEnemyCount;
  int get tickCount => _tickCount;
  bool get isBaseDestroyed => _isBaseDestroyed;

  int get _aliveEnemyCount =>
      _tanks.where((t) => t.isAlive && t.type.isEnemy).length;

  int get _alivePlayerCount =>
      _tanks.where((t) => t.isAlive && t.type.isPlayer).length;

  // ========== 输入处理 ==========

  void _processInputs(double dt) {
    for (final tank in _tanks) {
      if (!tank.isAlive || !tank.type.isPlayer) continue;
      final input = _playerInputs[tank.ownerPlayerIndex];
      if (input == null) {
        tank.isMoving = false;
        continue;
      }
      final (dir, firing) = input;

      // 移动
      if (dir != null) {
        if (tank.direction == dir) {
          tank.isMoving = true;
        } else if (_isGridAligned(tank)) {
          tank.direction = dir;
          _snapToGrid(tank);
          tank.isMoving = true;
        } else {
          tank.isMoving = true;
        }
      } else {
        tank.isMoving = false;
      }

      // 射击
      if (firing && tank.shootCooldown <= 0) {
        _fireBullet(tank);
        tank.shootCooldown = TankBattleConstants.shootCooldownTicks;
      }
    }
  }

  // ========== AI ==========

  void _updateAI() {
    for (final tank in _tanks) {
      if (!tank.isAlive || !tank.type.isEnemy) continue;

      // 每 N 帧做一次方向决策 (保持与 20fps 相同的实际频率)
      final decisionInterval = (10 + (5 - min(level, 5))) * 3;
      if (_tickCount % decisionInterval == tank.id % decisionInterval) {
        _aiDecideDirection(tank);
      }

      // 每帧判断射击 (60fps 下频率降低为 1/3 保持平衡)
      final fireRate = (0.02 + level * 0.005) / 3;
      if (_random.nextDouble() < fireRate) {
        if (tank.shootCooldown <= 0) {
          _fireBullet(tank);
          tank.shootCooldown = TankBattleConstants.shootCooldownTicks;
        }
      }

      // 卡墙检测 (60fps 下 tick 数 ×3)
      if (tank.isMoving && tank.stuckTicks > 30) {
        _aiDecideDirection(tank, forceChange: true);
        tank.stuckTicks = 0;
      }
    }
  }

  void _aiDecideDirection(_Tank tank, {bool forceChange = false}) {
    if (!forceChange && _random.nextDouble() < 0.7) {
      // 继续当前方向
      tank.isMoving = true;
      return;
    }

    // 找到最近的目标 (玩家坦克或基地)
    Direction bestDir;
    if (!forceChange && _random.nextDouble() < 0.5) {
      // 朝目标移动
      bestDir = _directionTowardTarget(tank);
    } else {
      // 随机方向
      bestDir = Direction.values[_random.nextInt(4)];
    }

    if (tank.direction != bestDir && _isGridAligned(tank)) {
      tank.direction = bestDir;
      _snapToGrid(tank);
    }
    tank.isMoving = true;
  }

  Direction _directionTowardTarget(_Tank tank) {
    // 找目标
    double targetX = _basePos?.$2.toDouble() ?? 9.0;
    double targetY = _basePos?.$1.toDouble() ?? 18.0;

    // 优先朝玩家坦克
    final players = _tanks.where((t) => t.isAlive && t.type.isPlayer).toList();
    if (players.isNotEmpty) {
      final nearest = players.reduce((a, b) {
        final da = (a.x - tank.x).abs() + (a.y - tank.y).abs();
        final db = (b.x - tank.x).abs() + (b.y - tank.y).abs();
        return da < db ? a : b;
      });
      if (_random.nextDouble() < 0.4) {
        targetX = nearest.x;
        targetY = nearest.y;
      }
    }

    final dx = targetX - tank.x;
    final dy = targetY - tank.y;
    if (dx.abs() > dy.abs()) {
      return dx > 0 ? Direction.right : Direction.left;
    } else {
      return dy > 0 ? Direction.down : Direction.up;
    }
  }

  // ========== 移动 ==========

  void _moveTanks(double dt) {
    for (final tank in _tanks) {
      if (!tank.isAlive || !tank.isMoving) continue;

      final prevX = tank.x;
      final prevY = tank.y;
      final speed = tank.type.baseSpeed.toDouble();
      final move = speed * dt;

      tank.x += tank.direction.dx * move;
      tank.y += tank.direction.dy * move;

      // 边界约束
      tank.x = tank.x.clamp(0.0, TankBattleConstants.gridSize - 1.0);
      tank.y = tank.y.clamp(0.0, TankBattleConstants.gridSize - 1.0);

      // 碰撞检测
      if (_tankCollidesWithWall(tank) || _tankCollidesWithTanks(tank)) {
        tank.x = prevX;
        tank.y = prevY;
        tank.stuckTicks++;
      } else {
        tank.stuckTicks = 0;
      }

      // 格点吸附
      if (_isGridAligned(tank)) {
        _snapToGrid(tank);
      }
    }

    // 递减冷却和无敌帧
    for (final tank in _tanks) {
      if (!tank.isAlive) continue;
      if (tank.shootCooldown > 0) tank.shootCooldown--;
      if (tank.invincibleFrames > 0) tank.invincibleFrames--;
    }
  }

  bool _tankCollidesWithWall(_Tank tank) {
    final left = tank.x + (1 - TankBattleConstants.tankHitboxSize) / 2;
    final top = tank.y + (1 - TankBattleConstants.tankHitboxSize) / 2;
    final right = left + TankBattleConstants.tankHitboxSize;
    final bottom = top + TankBattleConstants.tankHitboxSize;

    // 检查四个角
    for (final (cx, cy) in [
      (left, top),
      (right - 0.01, top),
      (left, bottom - 0.01),
      (right - 0.01, bottom - 0.01),
    ]) {
      final col = cx.floor();
      final row = cy.floor();
      if (row < 0 ||
          row >= TankBattleConstants.gridSize ||
          col < 0 ||
          col >= TankBattleConstants.gridSize) {
        return true;
      }
      if (_map[row][col].blocksTank) return true;
    }
    return false;
  }

  bool _tankCollidesWithTanks(_Tank tank) {
    final myLeft = tank.x + (1 - TankBattleConstants.tankHitboxSize) / 2;
    final myTop = tank.y + (1 - TankBattleConstants.tankHitboxSize) / 2;
    final myRight = myLeft + TankBattleConstants.tankHitboxSize;
    final myBottom = myTop + TankBattleConstants.tankHitboxSize;

    for (final other in _tanks) {
      if (other.id == tank.id || !other.isAlive) continue;
      final oLeft = other.x + (1 - TankBattleConstants.tankHitboxSize) / 2;
      final oTop = other.y + (1 - TankBattleConstants.tankHitboxSize) / 2;
      final oRight = oLeft + TankBattleConstants.tankHitboxSize;
      final oBottom = oTop + TankBattleConstants.tankHitboxSize;

      if (myLeft < oRight &&
          myRight > oLeft &&
          myTop < oBottom &&
          myBottom > oTop) {
        return true;
      }
    }
    return false;
  }

  // ========== 子弹移动 ==========

  void _moveBullets(double dt) {
    for (final bullet in _bullets) {
      if (!bullet.isActive) continue;
      final speed = TankBattleConstants.bulletSpeed.toDouble();
      bullet.x += bullet.direction.dx * speed * dt;
      bullet.y += bullet.direction.dy * speed * dt;

      // 出界
      if (bullet.x < 0 ||
          bullet.x >= TankBattleConstants.gridSize ||
          bullet.y < 0 ||
          bullet.y >= TankBattleConstants.gridSize) {
        bullet.isActive = false;
      }
    }
  }

  // ========== 碰撞检测 ==========

  void _checkCollisions() {
    for (final bullet in _bullets) {
      if (!bullet.isActive) continue;

      // 子弹 vs 墙壁
      _checkBulletVsWall(bullet);

      if (!bullet.isActive) continue;

      // 子弹 vs 坦克
      _checkBulletVsTanks(bullet);

      if (!bullet.isActive) continue;

      // 子弹 vs 子弹
      _checkBulletVsBullets(bullet);
    }
  }

  void _checkBulletVsWall(_Bullet bullet) {
    // 检查子弹路径上的多个位置，防止高速子弹穿墙
    final step = TankBattleConstants.bulletSpeed * TankBattleConstants.tickDuration;
    for (double offset = 0; offset <= step; offset += 0.25) {
      final checkX = bullet.x + bullet.direction.dx * offset;
      final checkY = bullet.y + bullet.direction.dy * offset;
      final col = checkX.floor().clamp(0, TankBattleConstants.gridSize - 1);
      final row = checkY.floor().clamp(0, TankBattleConstants.gridSize - 1);

      final tile = _map[row][col];
      if (tile.isDestructible) {
        _map[row][col] = TileType.empty;
        bullet.isActive = false;
        _addExplosion(col.toDouble(), row.toDouble(), isLarge: false);
        return;
      } else if (tile == TileType.steel) {
        bullet.isActive = false;
        _addExplosion(col.toDouble(), row.toDouble(), isLarge: false);
        return;
      } else if (tile == TileType.base) {
        _map[row][col] = TileType.baseDestroyed;
        bullet.isActive = false;
        _isBaseDestroyed = true;
        _addExplosion(col.toDouble(), row.toDouble(), isLarge: true);
        return;
      }
    }
  }

  void _checkBulletVsTanks(_Bullet bullet) {
    for (final tank in _tanks) {
      if (!tank.isAlive) continue;
      if (tank.invincibleFrames > 0) continue;
      // 友军免伤: 同阵营不互相伤害 (玩家之间、敌人之间)
      final bothPlayers = tank.type.isPlayer && bullet.ownerPlayerIndex >= 0;
      final bothEnemies = tank.type.isEnemy && bullet.ownerPlayerIndex < 0;
      if (bothPlayers || bothEnemies) continue;

      final tankLeft = tank.x + (1 - TankBattleConstants.tankHitboxSize) / 2;
      final tankTop = tank.y + (1 - TankBattleConstants.tankHitboxSize) / 2;
      final tankRight = tankLeft + TankBattleConstants.tankHitboxSize;
      final tankBottom = tankTop + TankBattleConstants.tankHitboxSize;

      final bSize = TankBattleConstants.bulletHitboxSize;
      final bLeft = bullet.x - bSize / 2;
      final bTop = bullet.y - bSize / 2;
      final bRight = bLeft + bSize;
      final bBottom = bTop + bSize;

      if (bLeft < tankRight &&
          bRight > tankLeft &&
          bTop < tankBottom &&
          bBottom > tankTop) {
        bullet.isActive = false;
        tank.hp--;
        if (tank.hp <= 0) {
          tank.isAlive = false;
          _addExplosion(tank.x, tank.y, isLarge: true);
          if (tank.type.isEnemy) {
            _score += tank.type.scoreValue;
          } else {
            // 玩家死亡
            _livesRemaining--;
          }
        }
        return;
      }
    }
  }

  void _checkBulletVsBullets(_Bullet bullet) {
    for (final other in _bullets) {
      if (other.id == bullet.id || !other.isActive) continue;
      final dist =
          (bullet.x - other.x).abs() + (bullet.y - other.y).abs();
      if (dist < 0.5) {
        bullet.isActive = false;
        other.isActive = false;
        _addExplosion(
          (bullet.x + other.x) / 2,
          (bullet.y + other.y) / 2,
          isLarge: false,
        );
        return;
      }
    }
  }

  // ========== 生成管理 ==========

  void _manageSpawns() {
    if (_spawnedEnemies >= _totalEnemies) return;
    if (_aliveEnemyCount >= TankBattleConstants.maxEnemiesOnField) return;

    _spawnTimer++;
    if (_spawnTimer >= TankBattleConstants.spawnIntervalTicks) {
      _spawnTimer = 0;
      _spawnEnemy();
    }
  }

  void _spawnEnemy() {
    // 选择生成点
    final spawnIdx = _spawnedEnemies % SpawnPoints.enemy.length;
    final (row, col) = SpawnPoints.enemy[spawnIdx];

    // 检查生成点是否被占用
    for (final tank in _tanks) {
      if (!tank.isAlive) continue;
      if ((tank.x - col).abs() < 1.5 && (tank.y - row).abs() < 1.5) {
        return; // 被占用，跳过
      }
    }

    // 选择敌人类型
    final type = _pickEnemyType();
    _tanks.add(_Tank(
      id: _nextTankId++,
      x: col.toDouble(),
      y: row.toDouble(),
      direction: Direction.down,
      type: type,
      hp: type.maxHp,
      ownerPlayerIndex: -1,
    ));
    _spawnedEnemies++;
  }

  TankType _pickEnemyType() {
    final roll = _random.nextDouble();
    final armorChance = 0.1 + level * 0.04;
    final heavyChance = level >= 5 ? (level - 4) * 0.04 : 0.0;
    final fastChance = 0.2 + level * 0.02;

    if (roll < heavyChance) return TankType.enemyHeavy;
    if (roll < heavyChance + armorChance) return TankType.enemyArmor;
    if (roll < heavyChance + armorChance + fastChance) return TankType.enemyFast;
    return TankType.enemyBasic;
  }

  // ========== 胜负判定 ==========

  void _checkWinLose() {
    if (_isBaseDestroyed) {
      _isGameOver = true;
      return;
    }
    if (_livesRemaining <= 0 && _alivePlayerCount == 0) {
      _isGameOver = true;
      return;
    }
    if (_spawnedEnemies >= _totalEnemies && _aliveEnemyCount == 0) {
      _score += TankBattleConstants.levelCompleteBonus;
      _isLevelComplete = true;
    }
  }

  // ========== 辅助 ==========

  void _fireBullet(_Tank tank) {
    // 炮口前方（炮管尖端 + 半个子弹大小）
    final bx = tank.x + 0.5 + tank.direction.dx * 0.52;
    final by = tank.y + 0.5 + tank.direction.dy * 0.52;
    _bullets.add(_Bullet(
      id: _nextBulletId++,
      x: bx,
      y: by,
      direction: tank.direction,
      ownerId: tank.id,
      ownerPlayerIndex: tank.ownerPlayerIndex,
    ));
  }

  void _addExplosion(double x, double y, {required bool isLarge}) {
    _explosions.add(_Explosion(x: x, y: y, frame: 0, isLarge: isLarge));
  }

  bool _isGridAligned(_Tank tank) {
    final fx = tank.x % 1.0;
    final fy = tank.y % 1.0;
    final t = TankBattleConstants.gridSnapThreshold;
    return (fx < t || fx > 1.0 - t) && (fy < t || fy > 1.0 - t);
  }

  void _snapToGrid(_Tank tank) {
    tank.x = tank.x.roundToDouble();
    tank.y = tank.y.roundToDouble();
  }

  void _cleanup() {
    // 移除不活跃的子弹
    _bullets.removeWhere((b) => !b.isActive);

    // 推进爆炸动画
    for (final exp in _explosions) {
      exp.frame++;
    }
    _explosions
        .removeWhere((e) => e.frame >= TankBattleConstants.explosionDurationTicks);

    // 移除死亡超过一段时间的坦克 (保留尸体用于渲染)
    // 敌人死后立即移除，玩家死后由 respawn 逻辑处理
    _tanks.removeWhere((t) => !t.isAlive && t.type.isEnemy);
  }

  /// 玩家重生 (游戏循环外调用)。
  void respawnPlayer(int playerIndex) {
    final existing = _tanks.where(
        (t) => t.type.isPlayer && t.ownerPlayerIndex == playerIndex);
    if (existing.isNotEmpty) {
      _tanks.removeWhere(
          (t) => t.type.isPlayer && t.ownerPlayerIndex == playerIndex);
    }
    if (_livesRemaining <= 0) return;

    final (row, col) =
        SpawnPoints.player[playerIndex % SpawnPoints.player.length];
    _tanks.add(_Tank(
      id: _nextTankId++,
      x: col.toDouble(),
      y: row.toDouble(),
      direction: Direction.up,
      type: playerIndex == 0 ? TankType.player1 : TankType.player2,
      hp: 1,
      ownerPlayerIndex: playerIndex,
    ));
  }

  // ========== 快照 ==========

  TankBattleState toSnapshot({
    required TankBattlePhase phase,
    bool isSolo = true,
    String selfName = '',
    String opponentName = '',
  }) {
    return TankBattleState(
      phase: phase,
      map: _map.map((row) => List<TileType>.from(row)).toList(),
      tanks: _tanks
          .where((t) => t.isAlive)
          .map((t) => TankSnapshot(
                id: t.id,
                x: t.x,
                y: t.y,
                direction: t.direction,
                type: t.type,
                hp: t.hp,
                isAlive: t.isAlive,
                invincibleFrames: t.invincibleFrames,
                isMoving: t.isMoving,
                ownerPlayerIndex: t.ownerPlayerIndex,
              ))
          .toList(),
      bullets: _bullets
          .where((b) => b.isActive)
          .map((b) => BulletSnapshot(
                id: b.id,
                x: b.x,
                y: b.y,
                direction: b.direction,
                ownerId: b.ownerId,
                ownerPlayerIndex: b.ownerPlayerIndex,
              ))
          .toList(),
      explosions: _explosions
          .map((e) => ExplosionSnapshot(
                x: e.x,
                y: e.y,
                frame: e.frame,
                isLarge: e.isLarge,
              ))
          .toList(),
      currentLevel: level,
      livesRemaining: _livesRemaining,
      enemiesRemaining: enemiesRemaining,
      score: _score,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
      isBaseDestroyed: _isBaseDestroyed,
      gameTick: _tickCount,
    );
  }

  /// 获取地图变化 (用于 PvP 增量同步)。
  List<List<int>> getMapChanges(List<List<TileType>> originalMap) {
    final changes = <List<int>>[];
    for (int r = 0; r < TankBattleConstants.gridSize; r++) {
      for (int c = 0; c < TankBattleConstants.gridSize; c++) {
        if (_map[r][c] != originalMap[r][c]) {
          changes.add([r, c, _map[r][c].index]);
        }
      }
    }
    return changes;
  }
}
