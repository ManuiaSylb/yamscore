class Game {
  final int? id;
  final String date;
  List<String> players;
  Map<String, int?> finalScores; 

  Game({
    this.id,
    required this.date,
    List<String>? players,
    Map<String, int?>? finalScores,
  })  : players = players ?? [],
        finalScores = finalScores ?? {};

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
    };
  }

  factory Game.fromMap(Map<String, dynamic> map) {
    return Game(
      id: map['id'] as int?,
      date: map['date'] as String,
      players: [], 
      finalScores: {}, 
    );
  }
}