/// 扑克收集战 — 游戏核心逻辑。
library;

import 'dart:math';
import 'package:gomoku_app/features/card_battle/constants/card_battle_constants.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_card.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_combination.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_state.dart';

class CardBattleEngine {
  final Random _random;

  late List<GameCard> _deck;
  late List<GameCard> _playerHand;
  late List<GameCard> _opponentHand;
  List<GameCard> _playerCollected = [];
  List<GameCard> _opponentCollected = [];

  // 当前轮
  List<GameCard> _tableCards = [];
  List<GameCard> _playerTableCards = [];
  List<GameCard> _opponentTableCards = [];
  CardCombo? _currentCombo;
  bool _lastPlayWasPass = false;
  int _firstPlayer;
  int _turnPlayerIndex;
  int _roundNumber = 0;
  bool _lastRoundPassed = false;

  bool _isGameOver = false;
  CardBattleStatus _finalStatus = CardBattleStatus.playing;
  String? _resultMessage;

  CardBattleEngine(int seed, int firstPlayer)
      : _random = Random(seed),
        _firstPlayer = firstPlayer,
        _turnPlayerIndex = firstPlayer;

  // ========== 初始化 ==========

  void initGame() {
    _deck = GameDeck.shuffleDeck(_random.nextInt(1 << 31));
    final (pHand, deck1) = GameDeck.dealCards(_deck, 5);
    final (oHand, deck2) = GameDeck.dealCards(deck1, 5);
    _playerHand = List.from(pHand);
    _opponentHand = List.from(oHand);
    _deck = deck2;
    _roundNumber = 1;
    _sortHands();
  }

  // ========== 公共查询 ==========

  List<GameCard> get playerHand => List.unmodifiable(_playerHand);
  List<GameCard> get opponentHand => List.unmodifiable(_opponentHand);
  List<GameCard> get playerCollected => List.unmodifiable(_playerCollected);
  List<GameCard> get opponentCollected => List.unmodifiable(_opponentCollected);
  List<GameCard> get tableCards => List.unmodifiable(_tableCards);
  List<GameCard> get playerTableCards => List.unmodifiable(_playerTableCards);
  List<GameCard> get opponentTableCards => List.unmodifiable(_opponentTableCards);
  CardCombo? get currentCombo => _currentCombo;
  bool get lastPlayWasPass => _lastPlayWasPass;
  int get turnPlayerIndex => _turnPlayerIndex;
  int get firstPlayer => _firstPlayer;
  int get roundNumber => _roundNumber;
  bool get lastRoundPassed => _lastRoundPassed;
  int get deckRemaining => _deck.length;
  bool get isGameOver => _isGameOver;
  CardBattleStatus get finalStatus => _finalStatus;
  String? get resultMessage => _resultMessage;

  // ========== 玩家出牌 ==========

  /// 玩家出牌。返回是否成功。
  bool playerPlay(List<GameCard> selectedCards) {
    if (_isGameOver) return false;
    if (_turnPlayerIndex != 0) return false;

    final combo = ComboDetector.detect(selectedCards);
    if (combo == null) return false; // 无效牌型

    // 检查所选牌是否都在玩家手牌中
    final handCopy = List<GameCard>.from(_playerHand);
    for (final card in selectedCards) {
      final idx = handCopy.indexOf(card);
      if (idx == -1) return false;
      handCopy.removeAt(idx);
    }

    // 检查是否能管上当前的牌
    if (_tableCards.isNotEmpty && _currentCombo != null) {
      if (!combo.canBeat(_currentCombo!)) return false;
    }

    // 执行出牌
    for (final card in selectedCards) {
      _playerHand.remove(card);
    }
    _playerTableCards.addAll(selectedCards);
    _tableCards.addAll(selectedCards);
    _currentCombo = combo;
    _lastPlayWasPass = false;
    _turnPlayerIndex = 1;
    _lastRoundPassed = false;

    // 检查对手是否没牌了
    if (_opponentHand.isEmpty && _deck.isEmpty) {
      _finalizeGame(0);
    }

    return true;
  }

  /// 玩家"过"。
  bool playerPass() {
    if (_isGameOver) return false;
    if (_tableCards.isEmpty || _currentCombo == null) return false;

    _lastPlayWasPass = true;
    _lastRoundPassed = true;

    // 对手（Player 1）赢下本轮
    _resolveRound(1);
    return true;
  }

  // ========== 对手/AI 出牌 ==========

  /// AI 对手出牌。返回动作描述（用于UI反馈）。
  /// 返回：{action: 'play'|'pass', cards: [...], combo: ...}
  Map<String, dynamic> aiPlay() {
    if (_isGameOver) {
      return {'action': 'pass'};
    }
    if (_opponentHand.isEmpty) {
      // 无手牌自动过
      return _aiPass();
    }

    // 如果桌上有牌需要管上
    if (_tableCards.isNotEmpty && _currentCombo != null) {
      final beaters = ComboDetector.findBeatingCombos(_opponentHand, _currentCombo!);

      // AI 决策：有 20% 概率故意过（迷惑对手）
      if (beaters.isNotEmpty && _random.nextDouble() < 0.2) {
        return _aiPass();
      }

      if (beaters.isNotEmpty) {
        // 选最优的（代价最小的）
        return _aiPlayCombo(beaters.first);
      }

      // 管不上，必须过
      return _aiPass();
    }

    // 桌面上没牌（刚收完牌），出任意牌
    return _aiLeadPlay();
  }

  /// 对手"过"（PvP 用）。
  bool opponentPass() {
    if (_isGameOver) return false;
    if (_tableCards.isEmpty || _currentCombo == null) return false;

    _lastPlayWasPass = true;
    _lastRoundPassed = true;

    // 玩家（Player 0）赢下本轮
    _resolveRound(0);
    return true;
  }

  /// 对手出牌（PvP 用，Guest 发来的操作）。
  bool opponentPlay(List<GameCard> selectedCards) {
    if (_isGameOver) return false;
    if (_turnPlayerIndex != 1) return false;

    final combo = ComboDetector.detect(selectedCards);
    if (combo == null) return false;

    final handCopy = List<GameCard>.from(_opponentHand);
    for (final card in selectedCards) {
      final idx = handCopy.indexOf(card);
      if (idx == -1) return false;
      handCopy.removeAt(idx);
    }

    if (_tableCards.isNotEmpty && _currentCombo != null) {
      if (!combo.canBeat(_currentCombo!)) return false;
    }

    for (final card in selectedCards) {
      _opponentHand.remove(card);
    }
    _opponentTableCards.addAll(selectedCards);
    _tableCards.addAll(selectedCards);
    _currentCombo = combo;
    _lastPlayWasPass = false;
    _turnPlayerIndex = 0;
    _lastRoundPassed = false;

    if (_playerHand.isEmpty && _deck.isEmpty) {
      _finalizeGame(1);
    }

    return true;
  }

  // ========== AI 内部方法 ==========

  Map<String, dynamic> _aiPass() {
    _lastPlayWasPass = true;
    _lastRoundPassed = true;
    // 玩家（Player 0）赢下本轮
    _resolveRound(0);
    return {'action': 'pass'};
  }

  Map<String, dynamic> _aiPlayCombo(CardCombo combo) {
    for (final card in combo.cards) {
      _opponentHand.remove(card);
    }
    _opponentTableCards.addAll(combo.cards);
    _tableCards.addAll(combo.cards);
    _currentCombo = combo;
    _lastPlayWasPass = false;
    _turnPlayerIndex = 0;
    _lastRoundPassed = false;

    if (_playerHand.isEmpty && _deck.isEmpty) {
      _finalizeGame(1);
    }

    return {
      'action': 'play',
      'cards': combo.cards,
      'combo': combo,
    };
  }

  Map<String, dynamic> _aiLeadPlay() {
    // 没牌可出（保护）
    if (_opponentHand.isEmpty) {
      return _aiPass();
    }

    // 优先出顺子，其次炸弹，然后对子/单张
    final hand = List<GameCard>.from(_opponentHand);

    // 尝试出顺子
    for (int len = 5; len >= 3; len--) {
      final straights =
          ComboDetector.findStraights(hand, len)..shuffle(_random);
      if (straights.isNotEmpty) {
        // 50% 概率出顺子
        if (_random.nextDouble() < 0.5) {
          return _aiPlayCombo(straights.first);
        }
      }
    }

    // 尝试出炸弹（3张同点）
    final rankGroups = <int, List<GameCard>>{};
    for (final card in hand) {
      if (!card.isJoker) {
        rankGroups.putIfAbsent(card.rank, () => []).add(card);
      }
    }
    for (final group in rankGroups.values) {
      if (group.length >= 3) {
        // 40% 概率出炸弹（保留）
        if (_random.nextDouble() < 0.4) {
          return _aiPlayCombo(CardCombo(
            type: ComboType.bomb,
            cards: List.from(group),
            primaryValue: group.first.compareValue,
            length: group.length,
          ));
        }
      }
    }

    // 出对子（如果有）
    for (final group in rankGroups.values) {
      if (group.length >= 2) {
        return _aiPlayCombo(CardCombo(
          type: ComboType.pair,
          cards: group.take(2).toList(),
          primaryValue: group.first.compareValue,
          length: 2,
        ));
      }
    }

    // 出最小的单张
    hand.sort((a, b) => a.compareValue.compareTo(b.compareValue));
    final lowest = hand.first;
    // 有王炸先不出
    final hasSmall = hand.any((c) => c.isSmallJoker);
    final hasBig = hand.any((c) => c.isBigJoker);
    if (lowest.isJoker && hasSmall && hasBig && hand.length >= 2) {
      // 找最小的非王牌
      for (final c in hand) {
        if (!c.isJoker) {
          return _aiPlayCombo(CardCombo(
            type: ComboType.single,
            cards: [c],
            primaryValue: c.compareValue,
            length: 1,
          ));
        }
      }
    }

    return _aiPlayCombo(CardCombo(
      type: ComboType.single,
      cards: [lowest],
      primaryValue: lowest.compareValue,
      length: 1,
    ));
  }

  // ========== 回合结算 ==========

  /// 赢下本轮，收走所有桌面牌，补牌。
  void _resolveRound(int winnerIndex) {
    final allCards = List<GameCard>.from(_tableCards);
    _tableCards.clear();
    _playerTableCards.clear();
    _opponentTableCards.clear();
    _currentCombo = null;
    _lastPlayWasPass = false;

    if (winnerIndex == 0) {
      _playerCollected.addAll(allCards);
    } else {
      _opponentCollected.addAll(allCards);
    }

    // 补牌到5张
    _drawToHandSize();

    // 赢家先出
    _turnPlayerIndex = winnerIndex;
    _roundNumber++;

    // 牌堆为空且当前出牌人无手牌 → 游戏结束，比较收集牌数
    if (_deck.isEmpty) {
      if (_turnPlayerIndex == 0 && _playerHand.isEmpty) {
        _finalizeGame(-1);
        return;
      } else if (_turnPlayerIndex == 1 && _opponentHand.isEmpty) {
        _finalizeGame(-1);
        return;
      }
    }
  }

  void _drawToHandSize() {
    final target = CardBattleConstants.handSize;

    // 交替抽牌：玩家→对手→玩家→对手→... 确保公平
    while ((_playerHand.length < target ||
            _opponentHand.length < target) &&
        _deck.isNotEmpty) {
      if (_playerHand.length < target) {
        _playerHand.add(_deck.removeAt(0));
      }
      if (_opponentHand.length < target && _deck.isNotEmpty) {
        _opponentHand.add(_deck.removeAt(0));
      }
    }

    // 抽牌后按大小从右到左排序（左边最大）
    _sortHands();
  
    // 如果牌堆已空且双方手牌都空了，游戏结束
    if (_deck.isEmpty && _playerHand.isEmpty && _opponentHand.isEmpty) {
      _finalizeGame(-1);
    }
  }
  
  /// 手牌从大到小排序（左边最大）。
  void _sortHands() {
    _playerHand.sort((a, b) => b.compareValue.compareTo(a.compareValue));
    _opponentHand.sort((a, b) => b.compareValue.compareTo(a.compareValue));
  }

  /// 游戏结束

  // ========== 游戏结束 ==========

  void _finalizeGame(int winnerIndex) {
    // 先将桌面牌给赢家（最后一手牌仍在桌上，未入收集区）
    if (_tableCards.isNotEmpty) {
      if (winnerIndex == 0) {
        _playerCollected.addAll(List.from(_tableCards));
      } else {
        _opponentCollected.addAll(List.from(_tableCards));
      }
      _tableCards.clear();
    }

    _isGameOver = true;
    if (winnerIndex == -1) {
      // 比较收集牌数决定胜负
      if (_playerCollected.length > _opponentCollected.length) {
        _finalStatus = CardBattleStatus.won;
        _resultMessage =
            '你赢了！收集了 ${_playerCollected.length} 张牌 (对手 ${_opponentCollected.length} 张)';
      } else if (_opponentCollected.length > _playerCollected.length) {
        _finalStatus = CardBattleStatus.lost;
        _resultMessage =
            '你输了，收集了 ${_playerCollected.length} 张牌 (对手 ${_opponentCollected.length} 张)';
      } else {
        _finalStatus = CardBattleStatus.draw;
        _resultMessage = '平局！双方都收集了 ${_playerCollected.length} 张牌';
      }
    } else if (winnerIndex == 0) {
      _finalStatus = CardBattleStatus.won;
      _resultMessage =
          '你赢了！收集了 ${_playerCollected.length} 张牌 (对手 ${_opponentCollected.length} 张)';
    } else {
      _finalStatus = CardBattleStatus.lost;
      _resultMessage =
          '你输了，收集了 ${_playerCollected.length} 张牌 (对手 ${_opponentCollected.length} 张)';
    }
  }

  /// 强制结束（断线/退出）。
  void forceGameOver() {
    _isGameOver = true;
    _finalStatus = CardBattleStatus.disconnected;
    _resultMessage = '游戏已中断';
  }

  // ========== 快照 ==========

  CardBattleState toSnapshot({
    required CardBattlePhase phase,
    bool isSolo = true,
    String selfName = '',
    String opponentName = '',
  }) {
    return CardBattleState(
      phase: phase,
      status: _isGameOver
          ? _finalStatus
          : CardBattleStatus.playing,
      deck: List.from(_deck),
      playerHand: List.from(_playerHand),
      opponentHand: List.from(_opponentHand),
      tableCards: List.from(_tableCards),
      playerTableCards: List.from(_playerTableCards),
      opponentTableCards: List.from(_opponentTableCards),
      currentCombo: _currentCombo,
      lastPlayWasPass: _lastPlayWasPass,
      playerCollected: List.from(_playerCollected),
      opponentCollected: List.from(_opponentCollected),
      firstPlayer: _firstPlayer,
      turnPlayerIndex: _turnPlayerIndex,
      seed: 0,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
      resultMessage: _resultMessage,
      roundNumber: _roundNumber,
      lastRoundPassed: _lastRoundPassed,
    );
  }

  // ========== 序列化（PvP 同步用）==========

  Map<String, dynamic> toJson() => {
        'deck': _deck.map((c) => c.toJson()).toList(),
        'player_hand': _playerHand.map((c) => c.toJson()).toList(),
        'opponent_hand': _opponentHand.map((c) => c.toJson()).toList(),
        'player_collected':
            _playerCollected.map((c) => c.toJson()).toList(),
        'opponent_collected':
            _opponentCollected.map((c) => c.toJson()).toList(),
        'table_cards': _tableCards.map((c) => c.toJson()).toList(),
        'current_combo_type': _currentCombo?.type.index,
        'current_combo_value': _currentCombo?.primaryValue,
        'current_combo_length': _currentCombo?.length,
        'first_player': _firstPlayer,
        'turn_player_index': _turnPlayerIndex,
        'round_number': _roundNumber,
        'last_round_passed': _lastRoundPassed ? 1 : 0,
        'is_game_over': _isGameOver ? 1 : 0,
        'final_status': _finalStatus.index,
        'result_message': _resultMessage,
      };
}
