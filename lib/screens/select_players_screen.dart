import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/game.dart';
import '../models/player.dart';
import 'game_screen.dart';

class SelectPlayersScreen extends StatefulWidget {
  final Game game;
  const SelectPlayersScreen({super.key, required this.game});

  @override
  State<SelectPlayersScreen> createState() => _SelectPlayersScreenState();
}

class _PlayerOrderDialog extends StatefulWidget {
  final List<Player> players;

  const _PlayerOrderDialog({required this.players});

  @override
  _PlayerOrderDialogState createState() => _PlayerOrderDialogState();
}

class _PlayerOrderDialogState extends State<_PlayerOrderDialog> {
  late List<Player> orderedPlayers;

  @override
  void initState() {
    super.initState();
    orderedPlayers = List.from(widget.players);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Organisation des joueurs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Glisse les joueurs pour définir leur ordre.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ReorderableListView(
                shrinkWrap: true,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = orderedPlayers.removeAt(oldIndex);
                    orderedPlayers.insert(newIndex, item);
                  });
                },
                children: orderedPlayers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final player = entry.value;
                  return Card(
                    key: ValueKey(player.id),
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(player.name),
                      trailing: const Icon(Icons.drag_handle),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(orderedPlayers),
                  child: const Text('Commencer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectPlayersScreenState extends State<SelectPlayersScreen> {
  List<Player> allPlayers = [];
  Set<int> selectedPlayers = {};
  final TextEditingController _newPlayerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final data = await DatabaseHelper.instance.getAllPlayers();
    setState(() => allPlayers = data);
  }

  Future<void> _addPlayer() async {
  final name = _newPlayerController.text.trim();
  if (name.isEmpty) return;

  final db = DatabaseHelper.instance;
  await db.insertPlayer(Player(name: name));

  // Recharge la liste des joueurs
  await _loadPlayers();

  // Sélectionner automatiquement le joueur ajouté
  final addedPlayer = allPlayers.firstWhere((p) => p.name == name, orElse: () => Player(id: null, name: ''));
  if (addedPlayer.id != null) {
    setState(() {
      selectedPlayers.add(addedPlayer.id!);
    });
  }

  _newPlayerController.clear();
  }

  Future<void> _startGame() async {
    if (selectedPlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis au moins un joueur.')),
      );
      return;
    }

    // Convert selected players to list for reordering
    List<Player> orderedPlayers = allPlayers
        .where((p) => selectedPlayers.contains(p.id))
        .toList();

    // Show reorder dialog
    final List<Player>? reorderedPlayers = await showDialog<List<Player>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _PlayerOrderDialog(players: orderedPlayers);
      },
    );

    if (reorderedPlayers == null) return; // Dialog cancelled

    // Insert the game
    int gameId = widget.game.id ??
        await DatabaseHelper.instance.insertGame(widget.game);

    // Link players in their specified order
    for (int i = 0; i < reorderedPlayers.length; i++) {
      await DatabaseHelper.instance.linkPlayerToGame(
        gameId,
        reorderedPlayers[i].id!,
        order: i,
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(gameId: gameId),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sélection des joueurs')),
      body: SafeArea(
        // ✅ protège des barres système
        child: Column(
        children: [
          Expanded(
            child: ListView(
              children: allPlayers.map((p) {
                final selected = selectedPlayers.contains(p.id);
                return CheckboxListTile(
                  title: Text(p.name),
                  value: selected,
                  onChanged: (_) {
                    setState(() {
                      if (selected) {
                        selectedPlayers.remove(p.id);
                      } else {
                        selectedPlayers.add(p.id!);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newPlayerController,
                    textCapitalization: TextCapitalization.words,
                    autocorrect: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addPlayer(),
                    decoration: const InputDecoration(
                      labelText: 'Nouveau joueur',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addPlayer,
                  child: const Text('Ajouter'),
                ),
              ],
            ),
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                12,
                12,
                24,
              ), // 👈 petit padding bas
            child: ElevatedButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Démarrer la partie'),
            ),
            ),
        ],
      ),
      ),
    );
  }
}