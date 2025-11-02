// GameCard.dart
import 'package:flutter/material.dart';
import '../models/game.dart';

class GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onCheckboxChanged;

  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.selectionMode = false,
    this.isSelected = false,
    this.onCheckboxChanged,
  });

  @override
  Widget build(BuildContext context) {
    int? maxScore;
    String? winnerName;
    if (game.finalScores.isNotEmpty && game.finalScores.values.any((s) => s != null)) {
      maxScore = game.finalScores.values.whereType<int>().fold<int>(0, (a, b) => a > b ? a : b);
      winnerName = game.finalScores.entries.firstWhere(
        (e) => e.value == maxScore,
        orElse: () => MapEntry('', null),
      ).key;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: selectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: onCheckboxChanged,
              )
            : null,
        title: Text('Partie du ${game.date}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: game.players.map((player) {
            final score = game.finalScores[player];
            final isWinner = player == winnerName;
            return Text(
              score != null ? '$player ($score)' : '$player (non terminée)',
              style: TextStyle(
                fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        onTap: onTap,
      ),
    );
  }
}