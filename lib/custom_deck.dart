class CustomCard {
  String front;
  String back;
  String soundFile;
  bool selectedForReplay;  // Add this

  CustomCard({
    required this.front,
    required this.back,
    required this.soundFile,
    this.selectedForReplay = true,  // Default to true
  });

  Map<String, dynamic> toJson() => {
    'front': front,
    'back': back,
    'soundFile': soundFile,
    'selectedForReplay': selectedForReplay,
  };

  CustomCard.fromJson(Map<String, dynamic> json)
    : front = json['front'],
      back = json['back'],
      soundFile = json['soundFile'],
      selectedForReplay = json['selectedForReplay'] ?? true;
}

class CustomDeck {
  String name;
  List<CustomCard> cards;
  DateTime createdAt;
  bool halfReplayMode;     
  bool replayHidden;       
  bool uniqueSoundsOnly;   // Add this field

  CustomDeck({
    required this.name,
    required this.cards,
    DateTime? createdAt,
    this.halfReplayMode = false,
    this.replayHidden = true,
    this.uniqueSoundsOnly = false,  // Add default value
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'name': name,
    'cards': cards.map((card) => card.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'halfReplayMode': halfReplayMode,
    'replayHidden': replayHidden,
    'uniqueSoundsOnly': uniqueSoundsOnly,  // Add to JSON
  };

  CustomDeck.fromJson(Map<String, dynamic> json)
    : name = json['name'],
      cards = (json['cards'] as List)
          .map((card) => CustomCard.fromJson(card))
          .toList(),
      createdAt = DateTime.parse(json['createdAt']),
      halfReplayMode = json['halfReplayMode'] ?? false,
      replayHidden = json['replayHidden'] ?? true,
      uniqueSoundsOnly = json['uniqueSoundsOnly'] ?? false;  // Add from JSON
}