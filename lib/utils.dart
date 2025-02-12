import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'custom_deck.dart';
import 'package:flutter/material.dart';

class Utils {
  // Sound management
  static List<String> get availableSounds => List.generate(
    200, 
    (i) => 'CueSound${i + 1}_normalized.wav'
  );

  // Volume management
  static Future<double> getFlashCardVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('flashCardVolume') ?? 1.0;
  }

  static Future<void> setFlashCardVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('flashCardVolume', volume);
  }

  static Future<double> getReplayVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('replayVolume') ?? 1.0;
  }

  static Future<void> setReplayVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('replayVolume', volume);
  }

  // Deck management
  static Future<List<CustomDeck>> getCustomDecks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? decksJson = prefs.getString('customDecks');
    if (decksJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(decksJson);
    return decoded.map((json) => CustomDeck.fromJson(json)).toList();
  }

  static Future<void> saveCustomDecks(List<CustomDeck> decks) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(decks.map((deck) => deck.toJson()).toList());
    await prefs.setString('customDecks', encoded);
  }

  // Help dialogs
  static void showHelpDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Text(content, style: TextStyle(color: Colors.black)),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close', style: TextStyle(color: Colors.black)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  static void showScreenOffWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Warning', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          content: Text(
            "Please do not turn off your screen during active flashcard or replay sessions.",
            style: TextStyle(color: Colors.black),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close', style: TextStyle(color: Colors.black)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}