import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../db/database_helper.dart';
import '../models/player.dart';
import '../models/game.dart';

class GameScreen extends StatefulWidget {
  final int gameId;
  final ValueChanged<Map<int, int?>>? onScoreUpdated;

  const GameScreen({
    super.key,
    required this.gameId,
    this.onScoreUpdated,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  List<Player> players = [];
  Game? game;
  final Map<int, Map<String, int?>> scoresData = {};

  static const List<String> upperCombos = ['1', '2', '3', '4', '5', '6'];
  static const List<String> lowerCombos = [
    'Chance',
    'Brelan',
    'Carré',
    'Full',
    'Petite suite',
    'Grande suite',
    'Yams'
  ];
  static final List<String> combinations = [...upperCombos, ...lowerCombos];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final playersData = await DatabaseHelper.instance.getPlayersForGame(widget.gameId);
    final games = await DatabaseHelper.instance.getAllGames();
    final currentGame = games.firstWhere((g) => g.id == widget.gameId);
    final existingScores = await DatabaseHelper.instance.getYamsScores(widget.gameId);
    setState(() {
      players = playersData;
      game = currentGame;
      for (var p in players) {
        scoresData[p.id!] = Map<String, int?>.from(existingScores[p.id!] ?? {});
      }
    });
  }

  void _updateScore(int playerId, String combinaison, int? score) async {
    setState(() {
      scoresData[playerId] ??= {};
      scoresData[playerId]![combinaison] = score;
    });

    await DatabaseHelper.instance.saveYamsScores(widget.gameId, playerId, scoresData[playerId]!);

    if (_isPlayerDone(playerId)) {
      final total =
          _upperTotalFor(playerId) +
          _lowerTotalFor(playerId) +
          _bonusForUpper(playerId);
      await DatabaseHelper.instance.updateFinalScoreIfComplete(
        widget.gameId,
        playerId,
      );
    }

    if (widget.onScoreUpdated != null) {
      final Map<int, int?> finalScores = {};
      for (var p in scoresData.keys) {
        finalScores[p] = scoresData[p]!.values.every((v) => v != null)
            ? scoresData[p]!.values.fold<int>(0, (sum, v) => sum + (v ?? 0))
            : null;
      }
      widget.onScoreUpdated!(finalScores);
    }

    if (score != null) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _goToNextPlayer();
    }

    if (_allPlayersDone()) {
      _showEndGameDialog();
    }
  }

  void _goToNextPlayer() {
    if (players.isEmpty) return;
    int nextPage = (_currentPage + 1) % players.length;
    while (_isPlayerDone(players[nextPage].id!)) {
      nextPage = (nextPage + 1) % players.length;
      if (nextPage == _currentPage) break;
    }
    _controller.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _isPlayerDone(int playerId) {
    final data = scoresData[playerId] ?? {};
    return combinations.every((c) => data[c] != null);
  }

  bool _allPlayersDone() {
    return players.every((p) => _isPlayerDone(p.id!));
  }

  int _upperTotalFor(int playerId) {
    final data = scoresData[playerId] ?? {};
    return upperCombos.fold(0, (sum, c) => sum + (data[c] ?? 0));
  }

  int _lowerTotalFor(int playerId) {
    final data = scoresData[playerId] ?? {};
    return lowerCombos.fold(0, (sum, c) => sum + (data[c] ?? 0));
  }

  int _bonusForUpper(int playerId) {
    final upper = _upperTotalFor(playerId);
    return upper > 62 ? 35 : 0;
  }

  Future<int?> _getFinalScoreFromDb(int playerId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'game_players',
      columns: ['player_final_score'],
      where: 'game_id = ? AND player_id = ?',
      whereArgs: [widget.gameId, playerId],
    );
    if (result.isNotEmpty) return result.first['player_final_score'] as int?;
    return null;
  }

  List<int?> _getOptionsFor(String combination) {
    if (upperCombos.contains(combination)) {
      final face = int.parse(combination);
      return [null, 0, for (int i = 1; i <= 5; i++) i * face];
    }
    switch (combination) {
      case 'Brelan':
      case 'Chance':
        return [null, ...List.generate(26, (i) => i + 5)];
      case 'Carré':
        return [null, ...List.generate(26, (i) => i + 5), 40];
      case 'Full':
        return [null, 0, 25];
      case 'Petite suite':
        return [null, 0, 30];
      case 'Grande suite':
        return [null, 0, 40];
      case 'Yams':
        return [null, 0, 50];
      default:
        return [null, 0];
    }
  }

  Widget _diceIconFor(String combo) {
    String? assetPath;
    switch (combo) {
      case '1': assetPath = 'assets/icons/dice_1.svg'; break;
      case '2': assetPath = 'assets/icons/dice_2.svg'; break;
      case '3': assetPath = 'assets/icons/dice_3.svg'; break;
      case '4': assetPath = 'assets/icons/dice_4.svg'; break;
      case '5': assetPath = 'assets/icons/dice_5.svg'; break;
      case '6': assetPath = 'assets/icons/dice_6.svg'; break;
    }
    if (assetPath != null) {
      return SvgPicture.asset(
        assetPath,
        width: 28,
        height: 28,
        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
      );
    }
    return const SizedBox(width: 28, height: 28);
  }

  void _showEndGameDialog() async {
    final List<Map<String, dynamic>> results = [];
    for (var p in players) {
      final dbFinal = await _getFinalScoreFromDb(p.id!);
      final total = _upperTotalFor(p.id!) + _lowerTotalFor(p.id!) + _bonusForUpper(p.id!);
      results.add({'player': p.name, 'score': dbFinal ?? total});
    }
    results.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Classement final'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: results.length,
              itemBuilder: (context, index) {
                final r = results[index];
                return ListTile(
                  leading: Text('#${index + 1}'),
                  title: Text(r['player']),
                  trailing: Text(r['score'].toString()),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            )
          ],
        );
      },
    );
  }

  void _showLiveScores() {
    final List<Map<String, dynamic>> results = [];
    for (var p in players) {
      final total = _upperTotalFor(p.id!) + _lowerTotalFor(p.id!) + _bonusForUpper(p.id!);
      results.add({'player': p.name, 'score': total});
    }
    results.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Classement actuel'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: results.length,
              itemBuilder: (context, index) {
                final r = results[index];
                return ListTile(
                  leading: Text('#${index + 1}'),
                  title: Text(r['player']),
                  trailing: Text(r['score'].toString()),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 5, 94, 130),
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () {
                if (_currentPage > 0) {
                  _controller.animateToPage(
                    _currentPage - 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
            Expanded(
              child: Center(
                child: Text(
                  players.isNotEmpty ? players[_currentPage].name : '',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onPressed: () {
                if (_currentPage < players.length - 1) {
                  _controller.animateToPage(
                    _currentPage + 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.leaderboard, color: Colors.white),
              onPressed: _showLiveScores,
            ),
          ],
        ),
        leadingWidth: 0,
      ),
      body: players.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : PageView.builder(
              controller: _controller,
              itemCount: players.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final player = players[index];
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          Card(
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            margin: EdgeInsets.zero,
                            child: Column(
                              children: [
                                ...upperCombos.map((c) {
                                  final value = scoresData[player.id!]?[c];
                                  final options = _getOptionsFor(c);
                                  final isCompleted = value != null;
                                  return Column(
                                    children: [
                                      ListTile(
                                        dense: true,
                                        leading: _diceIconFor(c),
                                        title: Text(
                                          'Total de $c',
                                          style: TextStyle(
                                            color: isCompleted
                                                ? Colors.green
                                                : Colors.black,
                                            fontWeight: isCompleted
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        trailing: DropdownButtonHideUnderline(
                                          child: SizedBox(
                                            width: 60,
                                            child: DropdownButton<int?>(
                                              value: value,
                                              hint: const Text(
                                                '-',
                                                textAlign: TextAlign.center,
                                              ),
                                              isExpanded: true,
                                              style: TextStyle(
                                                color: isCompleted
                                                    ? Colors.green
                                                    : Colors.black,
                                                fontWeight: isCompleted
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                              items: options.map((opt) {
                                                return DropdownMenuItem<int?>(
                                                  value: opt,
                                                  child: SizedBox(
                                                    width: 40,
                                                    child: Text(
                                                      opt?.toString() ?? '-',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: isCompleted
                                                            ? Colors.green
                                                            : Colors.black,
                                                        fontWeight: isCompleted
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (val) => _updateScore(
                                                player.id!,
                                                c,
                                                val,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Divider(height: 1, thickness: 0.5),
                                    ],
                                  );
                                }),
                                Container(
                                  color: const Color.fromARGB(255, 5, 94, 130),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total du haut',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${_upperTotalFor(player.id!)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  color: const Color.fromARGB(255, 4, 73, 118),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Bonus si > 62 (35 points)',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${_bonusForUpper(player.id!)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...lowerCombos.map((c) {
                                  final value = scoresData[player.id!]?[c];
                                  final options = _getOptionsFor(c);
                                  final isCompleted = value != null;
                                  return Column(
                                    children: [
                                      ListTile(
                                        dense: true,
                                        title: Text(
                                          c,
                                          style: TextStyle(
                                            color: isCompleted
                                                ? Colors.green
                                                : Colors.black,
                                            fontWeight: isCompleted
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        trailing: DropdownButtonHideUnderline(
                                          child: SizedBox(
                                            width: 60,
                                            child: DropdownButton<int?>(
                                              value: value,
                                              hint: const Text(
                                                '-',
                                                textAlign: TextAlign.center,
                                              ),
                                              isExpanded: true,
                                              style: TextStyle(
                                                color: isCompleted
                                                    ? Colors.green
                                                    : Colors.black,
                                                fontWeight: isCompleted
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                              items: options.map((opt) {
                                                return DropdownMenuItem<int?>(
                                                  value: opt,
                                                  child: SizedBox(
                                                    width: 40,
                                                    child: Text(
                                                      opt?.toString() ?? '-',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: isCompleted
                                                            ? Colors.green
                                                            : Colors.black,
                                                        fontWeight: isCompleted
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (val) => _updateScore(
                                                player.id!,
                                                c,
                                                val,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Divider(height: 1, thickness: 0.5),
                                    ],
                                  );
                                }),
                                Container(
                                  color: const Color.fromARGB(255, 5, 94, 130),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total du bas',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${_lowerTotalFor(player.id!)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  color: const Color.fromARGB(255, 4, 73, 118),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'SCORE FINAL',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${_upperTotalFor(player.id!) + _lowerTotalFor(player.id!) + _bonusForUpper(player.id!)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}