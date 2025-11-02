import 'package:flutter/material.dart';

class PlayersNotifier extends ChangeNotifier {
  void notifyChange() => notifyListeners();
}

final playersNotifier = PlayersNotifier();