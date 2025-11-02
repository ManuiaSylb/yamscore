class Player {
  final int? id;
  final String name;

  Player({this.id, required this.name});

  Player copyWith({int? id, String? name}) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] is int ? map['id'] as int : (map['id'] != null ? int.tryParse(map['id'].toString()) : null),
      name: map['name'] as String,
    );
  }

  @override
  String toString() => 'Player(id: $id, name: $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Player && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);
}