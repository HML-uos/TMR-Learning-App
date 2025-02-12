import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'utils.dart';
import 'custom_deck.dart';

class DeckEditorScreen extends StatefulWidget {
 final CustomDeck? existingDeck;

 const DeckEditorScreen({super.key, this.existingDeck});

 @override
 State<DeckEditorScreen> createState() => _DeckEditorScreenState();
}

class _DeckEditorScreenState extends State<DeckEditorScreen> {
 final TextEditingController _nameController = TextEditingController();
 final TextEditingController _frontController = TextEditingController();
 final TextEditingController _backController = TextEditingController();
 final AudioPlayer _audioPlayer = AudioPlayer();
 
 List<CustomCard> _cards = [];
 List<String> _availableSounds = [];
 bool _isEditing = false;
 bool _halfReplayMode = false;
 bool _replayHidden = true;
 bool _uniqueSoundsOnly = false;  // Add this line near other state variables
 List<String> _usedSoundsInOtherDecks = [];

 @override
 void initState() {
   super.initState();
   _initializeDeck();
   _loadUsedSounds(); 
 }

 Future<void> _loadUsedSounds() async {
  final allDecks = await Utils.getCustomDecks();
  setState(() {
    _usedSoundsInOtherDecks = allDecks
        .where((d) => widget.existingDeck == null || d.name != widget.existingDeck!.name)
        .expand((d) => d.cards.map((c) => c.soundFile))
        .toList();
    
    if (widget.existingDeck?.uniqueSoundsOnly ?? false) {
      _uniqueSoundsOnly = true;
    }
    _updateAvailableSounds();
  });
}

 void _showHelpDialog() {
  Utils.showHelpDialog(
    context,
    'Create/Edit Deck',
    '• Give your deck a name\n\n'
    '• Add cards using the front and back text fields\n\n'
    '• Each card will be automatically assigned a sound that is unique for this deck. There are 200 sounds available.\n\n'
    '• You can preview sounds by clicking the play button\n\n'
    '• You can reassign sounds using the shuffle button, this will reassign all sounds in the deck.\n\n'
    '• Enable "Use Unique Sounds Only" to ensure sounds don\'t overlap with other decks. Decks with this option active share their pool of available sounds, so that each sounds for each card is not only unique for this deck, but also across all other decks. So decks that have this option active do not double use sounds, that are already being used in other decks with this option active. Once a deck has been saved with this option enabled, it can not be disabled again.\n\n'
    '• Enable half replay mode to only replay selected cards during sleep. This replays only half of the sounds associated with the flashcards during replay. Perfect for testing on your own whether the TMR actually works. Initially which cards have their sounds replayed is hidden, but by clicking on "Show Selection" all cards that will have their sound replayed have a yellow lightning icon next to them, while not reactivated cards have a grayed out icon instead. \n\n'
    '• Click on the save icon in the top right when you\'re done creating or editing your deck.\n\n',
  );
}

 void _initializeDeck() {
    if (widget.existingDeck != null) {
      _nameController.text = widget.existingDeck!.name;
      _cards = List.from(widget.existingDeck!.cards);
      _halfReplayMode = widget.existingDeck!.halfReplayMode;
      _replayHidden = widget.existingDeck!.replayHidden;
      _uniqueSoundsOnly = widget.existingDeck!.uniqueSoundsOnly;  // Add this line
      _isEditing = true;
      
      _availableSounds = Utils.availableSounds
          .where((sound) => !_cards.map((card) => card.soundFile).contains(sound))
          .toList();
    } else {
      _availableSounds = List.from(Utils.availableSounds);
    }
  }

 void _randomizeReplaySelection() {
   if (_halfReplayMode) {
     final selectedCount = (_cards.length / 2).ceil();
     _cards.shuffle();
     for (int i = 0; i < _cards.length; i++) {
       _cards[i].selectedForReplay = i < selectedCount;
     }
   } else {
     for (var card in _cards) {
       card.selectedForReplay = true;
     }
   }
 }

 void _updateAvailableSounds() {
  if (_uniqueSoundsOnly) {
    // Get all sounds currently in use (both in other decks and current deck)
    final allUsedSounds = {..._usedSoundsInOtherDecks, ..._cards.map((c) => c.soundFile)};
    _availableSounds = Utils.availableSounds
        .where((s) => !allUsedSounds.contains(s))
        .toList();
  } else {
    _availableSounds = Utils.availableSounds
        .where((sound) => !_cards.map((card) => card.soundFile).contains(sound))
        .toList();
  }
}

 void _addCard() {
  if (_frontController.text.isEmpty || _backController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please fill in both front and back of the card')),
    );
    return;
  }

  if (_availableSounds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Maximum number of cards reached (200)')),
    );
    return;
  }

  final randomSoundIndex = _availableSounds.length == 1 ? 0 : 
      DateTime.now().millisecondsSinceEpoch % _availableSounds.length;
  final selectedSound = _availableSounds[randomSoundIndex];
  
  setState(() {
    _cards.add(CustomCard(
      front: _frontController.text,
      back: _backController.text,
      soundFile: selectedSound,
      selectedForReplay: !_halfReplayMode,
    ));
    _updateAvailableSounds();
    _frontController.clear();
    _backController.clear();
    if (_halfReplayMode) {
      _randomizeReplaySelection();
    }
  });
}

void _deleteCard(int index) {
  setState(() {
    _cards.removeAt(index);
    _updateAvailableSounds();
    if (_halfReplayMode) {
      _randomizeReplaySelection();
    }
  });
}
 void _playSound(String soundFile) async {
   await _audioPlayer.play(AssetSource(soundFile));
 }

 void _reassignSounds() {
   setState(() {
     final allSounds = [..._availableSounds, ..._cards.map((c) => c.soundFile)];
     allSounds.shuffle();
     
     for (int i = 0; i < _cards.length; i++) {
       _cards[i].soundFile = allSounds[i];
     }
     
     _availableSounds = allSounds.sublist(_cards.length);
   });
 }

 void _saveDeck() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a deck name')),
      );
      return;
    }

    if (_cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one card')),
      );
      return;
    }

    final deck = CustomDeck(
      name: _nameController.text,
      cards: _cards,
      createdAt: widget.existingDeck?.createdAt,
      halfReplayMode: _halfReplayMode,
      replayHidden: _replayHidden,
      uniqueSoundsOnly: _uniqueSoundsOnly,  // Add this line
    );

    Navigator.pop(context, deck);
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(_isEditing ? 'Edit Deck' : 'Create New Deck',
          style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
      backgroundColor: Theme.of(context).colorScheme.background,
      foregroundColor: Theme.of(context).colorScheme.onBackground,
      actions: [
        IconButton(
          icon: Icon(Icons.save, color: Theme.of(context).colorScheme.onBackground),
          onPressed: _saveDeck,
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Deck Name',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _frontController,
                  decoration: InputDecoration(
                    labelText: 'Front',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _backController,
                  decoration: InputDecoration(
                    labelText: 'Back',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                onPressed: _addCard,
                child: Icon(Icons.add, color: Colors.black),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Switch(
                    value: _uniqueSoundsOnly,
                    onChanged: _isEditing ? null : (value) {
                      setState(() {
                        _uniqueSoundsOnly = value;
                        _updateAvailableSounds();
                      });
                    },
                  ),
                  Text(
                    'Unique Sounds Only',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                ],
              ),
              if (_uniqueSoundsOnly)
                Text(
                  '${_availableSounds.length} unique sounds available',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        if (_cards.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                
                TextButton.icon(
                  onPressed: _reassignSounds,
                  icon: Icon(Icons.shuffle),
                  label: Text('Reassign Sounds'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Switch(
                          value: _halfReplayMode,
                          onChanged: (value) {
                            setState(() {
                              _halfReplayMode = value;
                              _randomizeReplaySelection();
                            });
                          },
                        ),
                        Text(
                          'Half Replay Mode',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                      ],
                    ),
                    if (_halfReplayMode)
                      Row(
                        children: [
                          Switch(
                            value: !_replayHidden,
                            onChanged: (value) {
                              setState(() {
                                _replayHidden = !value;
                              });
                            },
                          ),
                          Text(
                            'Show Selection',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.shuffle),
                            onPressed: () {
                              setState(() {
                                _randomizeReplaySelection();
                              });
                            },
                            tooltip: 'Rerandomize replay selection',
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                final card = _cards[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.play_arrow),
                          onPressed: () => _playSound(card.soundFile),
                        ),
                        if (_halfReplayMode && !_replayHidden)
                          Icon(
                            Icons.bolt,
                            color: card.selectedForReplay ? Colors.orange : Colors.grey,
                          ),
                      ],
                    ),
                    title: Text(card.front),
                    subtitle: Text(card.back),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteCard(index),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    ),
    bottomNavigationBar: Padding(
      padding: EdgeInsets.only(left: 16.0, bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          FloatingActionButton(
            mini: true,
            child: Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
    ),
  );
}

 @override
 void dispose() {
   _nameController.dispose();
   _frontController.dispose();
   _backController.dispose();
   _audioPlayer.dispose();
   super.dispose();
 }
}