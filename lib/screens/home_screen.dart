import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../widgets/game_card.dart';
import 'select_players_screen.dart';
import 'game_screen.dart';
import '../notifiers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Game> games = [];
  Set<int> selectedGames = {};
  bool selectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadGames();
    playersNotifier.addListener(_loadGames);
  }

  @override
  void dispose() {
    playersNotifier.removeListener(_loadGames);
    super.dispose();
  }

  Future<void> _loadGames() async {
    final data = await DatabaseHelper.instance.getAllGames();
    final allPlayers = await DatabaseHelper.instance.getAllPlayers();

    for (var game in data) {
      final finalScoresData = await DatabaseHelper.instance.getFinalScores(game.id!);
      final Map<String, int?> finalScores = {};
      for (var playerName in game.players) {
        final playerObj = allPlayers.firstWhere(
          (p) => p.name == playerName,
          orElse: () => Player(id: -1, name: ''),
        );
        finalScores[playerName] =
            playerObj.id != -1 ? finalScoresData[playerObj.id] ?? null : null;
      }
      game.finalScores = finalScores;
    }
    setState(() => games = data);
  }

  void _createNewGame() {
    final newGame = Game(
      id: null,
      date: DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now()),
      players: [],
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectPlayersScreen(game: newGame),
      ),
    ).then((_) => _loadGames());
  }

  void _openGame(Game game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          gameId: game.id!,
          onScoreUpdated: (updatedScores) {
            setState(() {
              for (var playerName in game.players) {
                final playerId = updatedScores.keys.firstWhere(
                  (id) => updatedScores[id] != null,
                  orElse: () => -1,
                );
                game.finalScores[playerName] =
                    playerId != -1 ? updatedScores[playerId] : null;
              }
            });
          },
        ),
      ),
    ).then((_) => _loadGames());
  }

  void _deleteSelectedGames() async {
    final db = DatabaseHelper.instance;
    for (var id in selectedGames) {
      final database = await db.database;
      await database.delete('yams_scores', where: 'game_id = ?', whereArgs: [id]);
      await database.delete('game_players', where: 'game_id = ?', whereArgs: [id]);
      await database.delete('games', where: 'id = ?', whereArgs: [id]);
    }
    setState(() {
      selectedGames.clear();
      selectionMode = false;
    });
    await _loadGames();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('YamScore'),
        actions: [
          if (selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: selectedGames.isEmpty ? null : _deleteSelectedGames,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  selectionMode = false;
                  selectedGames.clear();
                });
              },
            ),
          ] else ...[
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'select') {
                  setState(() => selectionMode = true);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'select',
                  child: Text('Sélectionner des parties'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: games.isEmpty
          ? const Center(child: Text('Aucune partie enregistrée'))
          : ListView.builder(
              itemCount: games.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final game = games[index];
                final isSelected = selectedGames.contains(game.id);

                return GestureDetector(
                  onLongPress: () {
                    setState(() {
                      selectionMode = true;
                      selectedGames.add(game.id!);
                    });
                  },
                  child: GameCard(
                    game: game,
                    selectionMode: selectionMode,
                    isSelected: isSelected,
                    onCheckboxChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selectedGames.add(game.id!);
                        } else {
                          selectedGames.remove(game.id!);
                        }
                      });
                    },
                    onTap: selectionMode
                        ? () {
                            setState(() {
                              if (isSelected) {
                                selectedGames.remove(game.id!);
                              } else {
                                selectedGames.add(game.id!);
                              }
                            });
                          }
                        : () => _openGame(game),
                  ),
                );
              },
            ),
      floatingActionButton: !selectionMode
          ? FloatingActionButton(
              onPressed: _createNewGame,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}