import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/game.dart';
import '../models/player.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('yamscore.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE games(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE players(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE game_players(
        game_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        player_order INTEGER NOT NULL,
        player_final_score INTEGER DEFAULT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE,
        FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE,
        UNIQUE(game_id, player_order)
      )
    ''');

    await db.execute('''
      CREATE TABLE yams_scores(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        combinaison TEXT NOT NULL,
        score INTEGER,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE,
        FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE,
        UNIQUE(game_id, player_id, combinaison) ON CONFLICT REPLACE
      )
    ''');
  }

  Future<int> insertGame(Game game) async {
    final db = await instance.database;
    return await db.insert('games', {'date': game.date});
  }

  Future<List<Game>> getAllGames() async {
    final db = await instance.database;
    final games = await db.query('games', orderBy: 'id DESC');
    List<Game> result = [];
    for (var gameMap in games) {
      final game = Game.fromMap(gameMap);
      final players = await getPlayersForGame(game.id!);
      game.players = players.map((p) => p.name).toList();
      result.add(game);
    }
    return result;
  }

  Future<List<Player>> getAllPlayers() async {
    final db = await instance.database;
    final result = await db.query('players', orderBy: 'name');
    return result.map((json) => Player.fromMap(json)).toList();
  }

  Future<int> insertPlayer(Player player) async {
    final db = await instance.database;
    return await db.insert(
      'players',
      player.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> linkPlayerToGame(int gameId, int playerId, {required int order}) async {
    final db = await database;
    await db.insert('game_players', {
      'game_id': gameId,
      'player_id': playerId,
      'player_order': order,
      'player_final_score': null,
    });
  }

  Future<List<Player>> getPlayersForGame(int gameId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT p.id, p.name FROM players p
      INNER JOIN game_players gp ON p.id = gp.player_id
      WHERE gp.game_id = ?
      ORDER BY gp.player_order
    ''', [gameId]);
    return result.map((e) => Player.fromMap(e)).toList();
  }

  Future<void> saveYamsScores(int gameId, int playerId, Map<String, int?> scores) async {
    final db = await instance.database;
    final batch = db.batch();
    scores.forEach((combinaison, score) {
      batch.insert(
        'yams_scores',
        {
          'game_id': gameId,
          'player_id': playerId,
          'combinaison': combinaison,
          'score': score,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
    await updateFinalScoreIfComplete(gameId, playerId);
  }

  Future<Map<int, Map<String, int?>>> getYamsScores(int gameId) async {
    final db = await instance.database;
    final result = await db.query(
      'yams_scores',
      where: 'game_id = ?',
      whereArgs: [gameId],
    );
    final Map<int, Map<String, int?>> data = {};
    for (var row in result) {
      final playerId = row['player_id'] as int;
      final combinaison = row['combinaison'] as String;
      final score = row['score'] as int?;
      data[playerId] ??= {};
      data[playerId]![combinaison] = score;
    }
    return data;
  }

  Future<Map<int, int?>> getFinalScores(int gameId) async {
    final db = await instance.database;
    final result = await db.query(
      'game_players',
      columns: ['player_id', 'player_final_score'],
      where: 'game_id = ?',
      whereArgs: [gameId],
    );

    final Map<int, int?> finalScores = {};
    for (var row in result) {
      final playerId = row['player_id'] as int;
      final score = row['player_final_score'] as int?;
      finalScores[playerId] = score;
    }
    return finalScores;
  }

  Future<void> updateFinalScoreIfComplete(int gameId, int playerId) async {
  final db = await instance.database;

  const combinations = [
    '1','2','3','4','5','6',
    'Brelan','Carré','Full',
    'Petite suite','Grande suite','Yams','Chance'
  ];

  final countResult = await db.rawQuery('''
    SELECT COUNT(*) as count FROM yams_scores
    WHERE game_id = ? AND player_id = ? AND score IS NOT NULL
  ''', [gameId, playerId]);
  final filledCount = countResult.first['count'] as int? ?? 0;

  if (filledCount >= combinations.length) {
    final totalResult = await db.rawQuery('''
      SELECT SUM(score) as total FROM yams_scores
      WHERE game_id = ? AND player_id = ?
    ''', [gameId, playerId]);
    final total = (totalResult.first['total'] ?? 0) as int;

    await db.update(
      'game_players',
      {'player_final_score': total},
      where: 'game_id = ? AND player_id = ?',
      whereArgs: [gameId, playerId],
    );
  } else {
    await db.update(
      'game_players',
      {'player_final_score': null},
      where: 'game_id = ? AND player_id = ?',
      whereArgs: [gameId, playerId],
    );
  }
}

  Future<Map<int, Map<int, Map<String, int?>>>> getAllPlayerStats() async {
    final db = await instance.database;
    final result = await db.query('game_players');
    final stats = <int, Map<int, Map<String, int?>>>{};
    final games = <int, List<Map<String, dynamic>>>{};
    for (final row in result) {
      final gameId = row['game_id'] as int;
      games.putIfAbsent(gameId, () => []);
      games[gameId]!.add(row);
    }
    for (final gameEntry in games.entries) {
      final gameId = gameEntry.key;
      final players = gameEntry.value;
      final allHaveScores = players.every((p) => p['player_final_score'] != null);
      if (!allHaveScores) continue;
      final maxScore = players.map((p) => p['player_final_score'] as int? ?? 0).fold<int>(0, (prev, elem) => elem > prev ? elem : prev);
      for (final player in players) {
        final playerId = player['player_id'] as int;
        final score = player['player_final_score'] as int?;
        if (score == null) continue;
        stats.putIfAbsent(playerId, () => {});
        stats[playerId]!.putIfAbsent(gameId, () => {});
        stats[playerId]![gameId] = {
          'player_final_score': score,
          'player_total_bet': player['player_total_bet'] as int?,
          'player_total_plis': player['player_total_plis'] as int?,
          'win': score == maxScore ? 1 : 0,
        };
      }
    }
    return stats;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}