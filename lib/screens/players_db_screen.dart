import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/player.dart';
import '../notifiers.dart';

class PlayersDbScreen extends StatefulWidget {
  const PlayersDbScreen({super.key});

  @override
  State<PlayersDbScreen> createState() => _PlayersDbScreenState();
}

class _PlayersDbScreenState extends State<PlayersDbScreen> {
  List<Player> players = [];
  List<Player> filteredPlayers = [];
  Set<int> selectedPlayers = {};
  bool selectionMode = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlayers();
    playersNotifier.addListener(_loadPlayers);
  }

  @override
  void dispose() {
    playersNotifier.removeListener(_loadPlayers);
    super.dispose();
  }

  Future<void> _loadPlayers() async {
    final data = await DatabaseHelper.instance.getAllPlayers();
    setState(() {
      players = data;
      filteredPlayers = data;
    });
  }

  void _filterPlayers(String query) {
    setState(() {
      filteredPlayers = players
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _deleteSelectedPlayers() async {
    if (selectedPlayers.isEmpty) return;

    final db = await DatabaseHelper.instance.database;
    for (var playerId in selectedPlayers) {
      await db.delete('yams_scores', where: 'player_id = ?', whereArgs: [playerId]);
      await db.delete('game_players', where: 'player_id = ?', whereArgs: [playerId]);
      await db.delete('players', where: 'id = ?', whereArgs: [playerId]);
    }

    final allGames = await db.query('games');
    for (var game in allGames) {
      final gameId = game['id'] as int;
      final playersInGame = await db.query('game_players', where: 'game_id = ?', whereArgs: [gameId]);
      if (playersInGame.isEmpty) await db.delete('games', where: 'id = ?', whereArgs: [gameId]);
    }

    playersNotifier.notifyChange();
    await _loadPlayers();
    setState(() {
      selectionMode = false;
      selectedPlayers.clear();
    });
  }

  void _showAddPlayerDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter un joueur'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          autocorrect: true,
          decoration: const InputDecoration(hintText: 'Nom du joueur'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await DatabaseHelper.instance.insertPlayer(Player(name: name));
                playersNotifier.notifyChange();
                _loadPlayers();
              }
              Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPlayerStats(Player player) async {
    const upperCombos = ['1','2','3','4','5','6'];
    final db = await DatabaseHelper.instance.database;
    final allGames = await db.rawQuery('''
      SELECT gp.game_id, gp.player_final_score
      FROM game_players gp
      WHERE gp.player_id = ?
    ''', [player.id]);

    final finishedGames = allGames.where((g) => g['player_final_score'] != null).toList();
    final gamesPlayed = finishedGames.length;
    final allScores = await db.query('yams_scores', where: 'player_id = ?', whereArgs: [player.id]);
    final comboStats = <String>[];

    if (finishedGames.isEmpty || allScores.isEmpty) {
      comboStats.add('Aucune partie terminée');
    } else {
      final finishedGameIds = finishedGames.map((g) => g['game_id'] as int).toSet();
      int bonusCount = 0;
      for (var gid in finishedGameIds) {
        final scores = allScores.where((s) => s['game_id'] == gid).toList();
        final upperTotal = upperCombos.fold<int>(0, (sum, c) {
          final score = scores.firstWhere((s) => s['combinaison'] == c, orElse: () => {'score': 0})['score'] as int?;
          return sum + (score ?? 0);
        });
        if (upperTotal > 62) bonusCount++;
      }
      final bonusPercent = finishedGameIds.isNotEmpty
          ? ((bonusCount / finishedGameIds.length) * 100).toStringAsFixed(0)
          : '0';

      final scoreCombos = ['1','2','3','4','5','6','Chance','Brelan','Carré'];
      final percentCombos = ['Full','Petite suite','Grande suite','Yams'];

      for (var combo in scoreCombos) {
        final scores = allScores
            .where((s) => s['combinaison'] == combo && finishedGameIds.contains(s['game_id'] as int) && s['score'] != null)
            .map((s) => s['score'] as int)
            .toList();
        if (scores.isNotEmpty) {
          final avg = (scores.reduce((a, b) => a + b) / scores.length).toStringAsFixed(1);
          comboStats.add('Moyenne $combo : $avg');
        } else {
          comboStats.add('Moyenne $combo : Non jouée');
        }
      }
      comboStats.add('Bonus obtenu : $bonusPercent%');
      comboStats.add('─────────────');

      for (var combo in percentCombos) {
        final relevantScores = allScores
            .where((s) => s['combinaison'] == combo && finishedGameIds.contains(s['game_id'] as int))
            .map((s) => s['score'] as int? ?? 0)
            .where((score) => score > 0)
            .toList();

        final percent = relevantScores.isNotEmpty
            ? ((relevantScores.length / finishedGameIds.length) * 100).toStringAsFixed(0)
            : '0';

        comboStats.add('Pourcentage de $combo : $percent%');
      }
      comboStats.add('─────────────');
      final highScore = finishedGames.map((g) => g['player_final_score'] as int).reduce((a, b) => a > b ? a : b);
      comboStats.add('Meilleur score : $highScore');
    }

    int totalWins = 0;
    for (var game in finishedGames) {
      final gameId = game['game_id'] as int;
      final maxResult = await db.rawQuery('''
        SELECT MAX(player_final_score) as max_score
        FROM game_players
        WHERE game_id = ? AND player_final_score IS NOT NULL
      ''', [gameId]);
      final maxScore = maxResult.first['max_score'] as int? ?? 0;
      if ((game['player_final_score'] as int?) == maxScore) totalWins++;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Parties jouées : $gamesPlayed', style: const TextStyle(fontSize: 16)),
                Text('Victoires : $totalWins', style: const TextStyle(fontSize: 16, color: Colors.green)),
                const SizedBox(height: 16),
                const Text('Statistiques :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...comboStats.map((e) => Text(e, style: const TextStyle(fontSize: 14))),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Base de joueurs'),
        actions: [
          if (selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: selectedPlayers.isEmpty ? null : _deleteSelectedPlayers,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  selectionMode = false;
                  selectedPlayers.clear();
                });
              },
            ),
          ] else ...[
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'select') setState(() => selectionMode = true);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'select', child: Text('Sélectionner des joueurs')),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _filterPlayers,
              decoration: InputDecoration(
                hintText: 'Rechercher un joueur...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: filteredPlayers.isEmpty
                ? const Center(child: Text('Aucun joueur trouvé'))
                : ListView.builder(
                    itemCount: filteredPlayers.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final player = filteredPlayers[index];
                      final isSelected = selectedPlayers.contains(player.id);
                      return GestureDetector(
                        onLongPress: () {
                          setState(() {
                            selectionMode = true;
                            selectedPlayers.add(player.id!);
                          });
                        },
                        onTap: selectionMode ? () {
                          setState(() {
                            if (isSelected) selectedPlayers.remove(player.id!);
                            else selectedPlayers.add(player.id!);
                          });
                        } : () => _showPlayerStats(player),
                        child: Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: selectionMode
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) selectedPlayers.add(player.id!);
                                        else selectedPlayers.remove(player.id!);
                                      });
                                    },
                                  )
                                : const Icon(Icons.person_outline),
                            title: Text(player.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: !selectionMode
          ? FloatingActionButton(
              onPressed: _showAddPlayerDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}