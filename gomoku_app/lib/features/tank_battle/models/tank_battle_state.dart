/// 坦克大战不可变状态快照。
library;

import 'package:gomoku_app/features/tank_battle/constants/tank_battle_constants.dart';

/// 坦克快照。
class TankSnapshot {
  final int id;
  final double x;
  final double y;
  final Direction direction;
  final TankType type;
  final int hp;
  final bool isAlive;
  final int invincibleFrames;
  final bool isMoving;
  final int ownerPlayerIndex;

  const TankSnapshot({
    required this.id,
    required this.x,
    required this.y,
    required this.direction,
    required this.type,
    required this.hp,
    required this.isAlive,
    this.invincibleFrames = 0,
    this.isMoving = false,
    this.ownerPlayerIndex = -1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'dir': direction.index,
        'type': type.index,
        'hp': hp,
        'alive': isAlive,
        'inv': invincibleFrames,
        'mov': isMoving,
        'opi': ownerPlayerIndex,
      };

  factory TankSnapshot.fromJson(Map<String, dynamic> json) => TankSnapshot(
        id: json['id'] as int,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        direction: Direction.fromIndex(json['dir'] as int),
        type: TankType.values[json['type'] as int],
        hp: json['hp'] as int,
        isAlive: json['alive'] as bool,
        invincibleFrames: json['inv'] as int? ?? 0,
        isMoving: json['mov'] as bool? ?? false,
        ownerPlayerIndex: json['opi'] as int? ?? -1,
      );
}

/// 子弹快照。
class BulletSnapshot {
  final int id;
  final double x;
  final double y;
  final Direction direction;
  final int ownerId;
  final int ownerPlayerIndex;

  const BulletSnapshot({
    required this.id,
    required this.x,
    required this.y,
    required this.direction,
    required this.ownerId,
    required this.ownerPlayerIndex,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'dir': direction.index,
        'oid': ownerId,
        'opi': ownerPlayerIndex,
      };

  factory BulletSnapshot.fromJson(Map<String, dynamic> json) =>
      BulletSnapshot(
        id: json['id'] as int,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        direction: Direction.fromIndex(json['dir'] as int),
        ownerId: json['oid'] as int,
        ownerPlayerIndex: json['opi'] as int,
      );
}

/// 爆炸快照。
class ExplosionSnapshot {
  final double x;
  final double y;
  final int frame;
  final bool isLarge;

  const ExplosionSnapshot({
    required this.x,
    required this.y,
    required this.frame,
    this.isLarge = false,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'f': frame,
        'l': isLarge,
      };

  factory ExplosionSnapshot.fromJson(Map<String, dynamic> json) =>
      ExplosionSnapshot(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        frame: json['f'] as int,
        isLarge: json['l'] as bool? ?? false,
      );
}

/// 游戏状态快照 (不可变)。
class TankBattleState {
  final TankBattlePhase phase;
  final List<List<TileType>> map;
  final List<TankSnapshot> tanks;
  final List<BulletSnapshot> bullets;
  final List<ExplosionSnapshot> explosions;
  final int currentLevel;
  final int livesRemaining;
  final int enemiesRemaining;
  final int score;
  final bool isSolo;
  final String selfName;
  final String opponentName;
  final bool isBaseDestroyed;
  final int gameTick;

  const TankBattleState({
    required this.phase,
    required this.map,
    required this.tanks,
    required this.bullets,
    required this.explosions,
    required this.currentLevel,
    required this.livesRemaining,
    required this.enemiesRemaining,
    required this.score,
    required this.isSolo,
    required this.selfName,
    required this.opponentName,
    required this.isBaseDestroyed,
    required this.gameTick,
  });

  factory TankBattleState.initial() {
    return TankBattleState(
      phase: TankBattlePhase.loading,
      map: List.generate(
        TankBattleConstants.gridSize,
        (_) => List.filled(TankBattleConstants.gridSize, TileType.empty),
      ),
      tanks: const [],
      bullets: const [],
      explosions: const [],
      currentLevel: 1,
      livesRemaining: TankBattleConstants.initialLives,
      enemiesRemaining: 0,
      score: 0,
      isSolo: true,
      selfName: '',
      opponentName: '',
      isBaseDestroyed: false,
      gameTick: 0,
    );
  }

  TankBattleState copyWith({
    TankBattlePhase? phase,
    List<List<TileType>>? map,
    List<TankSnapshot>? tanks,
    List<BulletSnapshot>? bullets,
    List<ExplosionSnapshot>? explosions,
    int? currentLevel,
    int? livesRemaining,
    int? enemiesRemaining,
    int? score,
    bool? isSolo,
    String? selfName,
    String? opponentName,
    bool? isBaseDestroyed,
    int? gameTick,
  }) {
    return TankBattleState(
      phase: phase ?? this.phase,
      map: map ?? this.map,
      tanks: tanks ?? this.tanks,
      bullets: bullets ?? this.bullets,
      explosions: explosions ?? this.explosions,
      currentLevel: currentLevel ?? this.currentLevel,
      livesRemaining: livesRemaining ?? this.livesRemaining,
      enemiesRemaining: enemiesRemaining ?? this.enemiesRemaining,
      score: score ?? this.score,
      isSolo: isSolo ?? this.isSolo,
      selfName: selfName ?? this.selfName,
      opponentName: opponentName ?? this.opponentName,
      isBaseDestroyed: isBaseDestroyed ?? this.isBaseDestroyed,
      gameTick: gameTick ?? this.gameTick,
    );
  }

  /// 序列化用于 PvP 状态同步。
  Map<String, dynamic> toJson() => {
        'tick': gameTick,
        'phase': phase.index,
        'tanks': tanks.map((t) => t.toJson()).toList(),
        'bullets': bullets.map((b) => b.toJson()).toList(),
        'explosions': explosions.map((e) => e.toJson()).toList(),
        'enemies_remaining': enemiesRemaining,
        'lives': livesRemaining,
        'score': score,
        'level': currentLevel,
        'base_alive': !isBaseDestroyed,
      };

  factory TankBattleState.fromSyncJson(
    Map<String, dynamic> json,
    List<List<TileType>> currentMap,
  ) {
    return TankBattleState(
      phase: TankBattlePhase.values[json['phase'] as int],
      map: currentMap,
      tanks: (json['tanks'] as List)
          .map((t) => TankSnapshot.fromJson(t as Map<String, dynamic>))
          .toList(),
      bullets: (json['bullets'] as List)
          .map((b) => BulletSnapshot.fromJson(b as Map<String, dynamic>))
          .toList(),
      explosions: (json['explosions'] as List)
          .map((e) => ExplosionSnapshot.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentLevel: json['level'] as int,
      livesRemaining: json['lives'] as int,
      enemiesRemaining: json['enemies_remaining'] as int,
      score: json['score'] as int,
      isSolo: false,
      selfName: '',
      opponentName: '',
      isBaseDestroyed: !(json['base_alive'] as bool),
      gameTick: json['tick'] as int,
    );
  }
}
