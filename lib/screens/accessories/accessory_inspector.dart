import 'package:flutter/material.dart';
import 'package:valorant_thunai/screens/accessories/player_card_inspect_screen.dart';
import 'package:valorant_thunai/screens/accessories/spray_inspect_screen.dart';

export 'player_card_inspect_screen.dart';
export 'spray_inspect_screen.dart';

class AccessoryInspector {
  static void showPlayerCard(BuildContext context, Map<String, dynamic> card) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerCardInspectScreen(card: card)),
    );
  }

  static void showSpray(BuildContext context, Map<String, dynamic> spray) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SprayInspectScreen(spray: spray)),
    );
  }
}
