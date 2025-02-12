import 'package:flutter/material.dart';
import 'utils.dart';
import 'custom_deck.dart';
import 'custom_flashcard_screen.dart';
import 'custom_replay_screen.dart';
import 'deck_editor_screen.dart';
import 'ambient_tmr_screen.dart';

class CustomDecksScreen extends StatefulWidget {
  const CustomDecksScreen({super.key});

  @override
  State<CustomDecksScreen> createState() => _CustomDecksScreenState();
}

class _CustomDecksScreenState extends State<CustomDecksScreen> {
  List<CustomDeck> _decks = [];

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  Future<void> _loadDecks() async {
    final decks = await Utils.getCustomDecks();
    setState(() {
      _decks = decks;
    });
  }

  Future<void> _deleteDeck(int index) async {
    setState(() {
      _decks.removeAt(index);
    });
    await Utils.saveCustomDecks(_decks);
  }

  void _showImportDialog() {
  final TextEditingController textController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Import Flashcards'),
      content: TextField(
        controller: textController,
        maxLines: 5,
        decoration: InputDecoration(
          hintText: 'Enter flashcards texts seperated by ","\ne.g. card1front, card1back, card2front, card2back, etc.',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.black)),
        ),
        TextButton(
          onPressed: () {
            _importFromText(textController.text);
            Navigator.pop(context);
          },
          child: Text('Import', style: TextStyle(color: Colors.black)),
        ),
      ],
    ),
  );
}

void _importFromText(String text) {
  // Remove any extra whitespace and split by comma
  final parts = text.split(',').map((e) => e.trim()).toList();
  
  if (parts.length % 2 == 0 && parts.isNotEmpty) {
    final cards = <CustomCard>[];
    final availableSounds = List<String>.from(Utils.availableSounds);

    for (int i = 0; i < parts.length; i += 2) {
      if (availableSounds.isEmpty) break;

      final soundIndex = DateTime.now().millisecondsSinceEpoch %
          availableSounds.length;
      cards.add(CustomCard(
        front: parts[i],
        back: parts[i + 1],
        soundFile: availableSounds[soundIndex],
      ));
      availableSounds.removeAt(soundIndex);
    }

    if (cards.isNotEmpty) {
      final deck = CustomDeck(
        name: 'Imported Deck ${_decks.length + 1}',
        cards: cards,
      );

      setState(() {
        _decks.add(deck);
      });
      Utils.saveCustomDecks(_decks);
    }
  }
}

  void _showHelpDialog() {
    Utils.showHelpDialog(
      context,
      'TMR Learning App',
      'Welcome to the TMR Learning App!\n\n'
          'With this app you can create your own flashcard decks and match sounds to each flashcard that can later be replayed for TMR supported learning. You can also play continuous ambient sounds during learning via the app and also replay those during the night. This is the main overview screen of the app, on the bottom you can find these options: \n\n'
          '• + Button: Create a new deck \n\n'
          '• File upload button: Quick create a new deck. Just enter a comma seperated string for all cards in your new deck. Quick added decks can not have the "Unique Sounds Only" option activated. More info on that on the deck editor screen help. \n\n'
          '• Speaker button: Start ambient TMR \n\n'
          'Once you have created a deck, you will find it and your other decks on this screen. You can see the deck\'s name and the number of flashcards in it. The half star icon signifies that the "Half Replay Mode" has been enabled, the musical note signifies that the "Unique Sounds Only" option is activated. More info on these options on the deck editor screen help. You can perform the following actions with your deck:\n\n'
          '• Pen: Edit your deck\n\n'
          '• Lightning: Start learning with your flashcards\n\n'
          '• Moon: Start nightly replay\n\n'
          '• Trashcan: Delete the deck\n\n',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TMR Learning App',
            style:
                TextStyle(color: Theme.of(context).colorScheme.onBackground)),
        backgroundColor: Theme.of(context).colorScheme.background,
      ),
      body: Column(
        children: [
          Expanded(
            child: _decks.isEmpty
                ? Center(
                    child: Text(
                      'No decks yet. Create one to get started!',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _decks.length,
                    itemBuilder: (context, index) {
                      final deck = _decks[index];
                      return Card(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(deck.name),
                          subtitle: Row(
                            children: [
                              Text('${deck.cards.length} cards'),
                              if (deck.halfReplayMode)
                                Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.star_half,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                                  ),
                                ),
                              if (deck.uniqueSoundsOnly)
                                Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.music_note,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () async {
                                  final updatedDeck =
                                      await Navigator.push<CustomDeck>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DeckEditorScreen(
                                        existingDeck: deck,
                                      ),
                                    ),
                                  );
                                  if (updatedDeck != null) {
                                    setState(() {
                                      _decks[index] = updatedDeck;
                                    });
                                    await Utils.saveCustomDecks(_decks);
                                  }
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.flash_on),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CustomFlashCardScreen(
                                        title: 'Learn ${deck.name}',
                                        deck: deck,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.nightlight),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CustomReplayScreen(
                                        deck: deck,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Delete Deck'),
                                    content: Text(
                                        'Are you sure you want to delete "${deck.name}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('Cancel',
                                            style:
                                                TextStyle(color: Colors.black)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteDeck(index);
                                        },
                                        child: Text('Delete',
                                            style:
                                                TextStyle(color: Colors.black)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(left: 32.0, bottom: 16.0),  // Increased left padding
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              mini: true,
              child: Icon(Icons.help_outline),
              onPressed: _showHelpDialog,
              heroTag: 'help',
            ),
            Row(
              children: [
                FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AmbientTMRScreen(),
                      ),
                    );
                  },
                  child: Icon(Icons.speaker),
                  heroTag: 'ambient',
                ),
                SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: _showImportDialog,
                  child: Icon(Icons.upload_file),
                  heroTag: 'import',
                ),
                SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: () async {
                    final newDeck = await Navigator.push<CustomDeck>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeckEditorScreen(),
                      ),
                    );
                    if (newDeck != null) {
                      setState(() {
                        _decks.add(newDeck);
                      });
                      await Utils.saveCustomDecks(_decks);
                    }
                  },
                  child: Icon(Icons.add),
                  heroTag: 'add',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
