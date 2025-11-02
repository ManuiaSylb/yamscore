import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Map<String, int> cumulativeScores = {};
  List<Map<String, dynamic>> bestScores = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final players = await DatabaseHelper.instance.getAllPlayers();
    final games = await DatabaseHelper.instance.getAllGames();
    final db = await DatabaseHelper.instance.database;

    Map<String, int> cumulative = {};
    List<Map<String, dynamic>> best = [];

    for (var player in players) {
      int total = 0;
      for (var game in games) {
        final result = await db.query(
          'game_players',
          columns: ['player_final_score'],
          where: 'game_id = ? AND player_id = ?',
          whereArgs: [game.id, player.id],
        );
        if (result.isNotEmpty && result.first['player_final_score'] != null) {
          int score = result.first['player_final_score'] as int;
          total += score;
          best.add({'name': player.name, 'score': score});  
        }
      }
      if (total > 0) cumulative[player.name] = total; 
    }

    best = best.where((e) => (e['score'] as int) > 0).toList(); 
    best.sort((a, b) => b['score'].compareTo(a['score']));

    setState(() {
      cumulativeScores = cumulative;
      bestScores = best;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedCumulative = cumulativeScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('Leaderboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Meilleurs scores'),
              Tab(text: 'Scores cumulés'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView.builder(
              itemCount: bestScores.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final item = bestScores[index];
                return Card(
                  color: Colors.white,
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    title: Text(item['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    trailing: Text(item['score'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
            ListView.builder(
              itemCount: sortedCumulative.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final entry = sortedCumulative[index];
                return Card(
                  color: Colors.white,
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    title: Text(entry.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    trailing: Text(entry.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}