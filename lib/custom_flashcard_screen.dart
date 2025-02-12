import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:math';
import 'utils.dart';
import 'custom_deck.dart';

class CustomFlashCardScreen extends StatefulWidget {
  final String title;
  final CustomDeck deck;

  const CustomFlashCardScreen({
    super.key, 
    required this.title,
    required this.deck,
  });

  @override
  State<CustomFlashCardScreen> createState() => _CustomFlashCardScreenState();
}

class _CustomFlashCardScreenState extends State<CustomFlashCardScreen> 
    with SingleTickerProviderStateMixin {
  bool _showFrontSide = true;
  int _currentCardIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _nextCardButtonEnabled = false;
  double _flashCardVolume = 1.0;
  bool _flipCardButtonEnabled = true;
  late List<CustomCard> _randomizedCards;
  late AnimationController _animationController;
  late Animation<Offset> _flyInAnimation;
  bool _isFirstCard = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _randomizeCards();
    _loadFlashCardVolume();
  }

  void _showHelpDialog() {
    Utils.showHelpDialog(
      context,
      'Learning Mode',
      '• View the front of each card\n'
      '• Click "Flip Card" to reveal the answer\n'
      '• A sound will play when the card is flipped\n'
      '• Click "Next Card" to continue\n'
      '• Adjust sound volume using the slider\n\n'
      'Turning your screen off or exiting the app will cancel the session.',
    );
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _flyInAnimation = Tween<Offset>(
      begin: const Offset(0.0, -2.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
  }

  Future<void> _loadFlashCardVolume() async {
    double volume = await Utils.getFlashCardVolume();
    setState(() {
      _flashCardVolume = volume;
    });
    _audioPlayer.setVolume(_flashCardVolume);
  }

  void _randomizeCards() {
    List<CustomCard> cards = List.from(widget.deck.cards);
    cards.shuffle(Random());
    setState(() {
      _randomizedCards = cards;
    });
  }

  void _flipCard() async {
    if (!_flipCardButtonEnabled) return;

    setState(() {
      _flipCardButtonEnabled = false;
      _nextCardButtonEnabled = false;
    });

    CustomCard currentCard = _randomizedCards[_currentCardIndex];
    await _audioPlayer.setVolume(_flashCardVolume);
    await _audioPlayer.play(AssetSource(currentCard.soundFile));

    setState(() {
      _showFrontSide = !_showFrontSide;
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      if (_showFrontSide) {
        _flipCardButtonEnabled = true;
        _nextCardButtonEnabled = false;
      } else {
        _flipCardButtonEnabled = true;
        _nextCardButtonEnabled = true;
      }
    });
  }

  void _nextCard() async {
    if (!_nextCardButtonEnabled || _showFrontSide) return;

    setState(() {
      _flipCardButtonEnabled = false;
      _nextCardButtonEnabled = false;
    });

    if (_currentCardIndex == _randomizedCards.length - 1) {
      _showCompletionDialog();
    } else {
      setState(() {
        _currentCardIndex++;
        _showFrontSide = true;
        _isFirstCard = false;
      });

      _animationController.forward(from: 0);

      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _flipCardButtonEnabled = true;
        _nextCardButtonEnabled = false;
      });
    }
  }

  Future<void> _showCompletionDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Session Complete',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          content: Text(
            'Congratulations! You have completed your learning session!\n\n'
            'Consider using the replay function while sleeping to strengthen your memories.',
            style: TextStyle(color: Colors.black),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.pop(context); // Dismiss the dialog
                Navigator.pop(context); // Return to the deck list
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard() {
    return Card(
      color: _showFrontSide ? Theme.of(context).colorScheme.surface : Color(0xFFFF9050),
      elevation: 4.0,
      child: SizedBox(
        width: 300.0,
        height: 200.0,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: AutoSizeText(
              _showFrontSide
                  ? _randomizedCards[_currentCardIndex].front
                  : _randomizedCards[_currentCardIndex].back,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: _showFrontSide ? Theme.of(context).colorScheme.onSurface : Color(0xFF102333),
                  ),
              textAlign: TextAlign.center,
              maxLines: 8,
              minFontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              'Progress',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: (_currentCardIndex + 1) / _randomizedCards.length,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.secondary),
            ),
          ),
          SizedBox(width: 10),
          Text(
            '${_currentCardIndex + 1} / ${_randomizedCards.length}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.background,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Icon(
                  Icons.volume_mute,
                  color: Theme.of(context).colorScheme.onBackground,
                  size: 24,
                ),
                Expanded(
                  child: Slider(
                    value: _flashCardVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    label: (_flashCardVolume * 100).round().toString(),
                    onChanged: (double value) {
                      setState(() {
                        _flashCardVolume = value;
                      });
                      _audioPlayer.setVolume(_flashCardVolume);
                      Utils.setFlashCardVolume(_flashCardVolume);
                    },
                  ),
                ),
                Icon(
                  Icons.volume_up,
                  color: Theme.of(context).colorScheme.onBackground,
                  size: 24,
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          _buildProgressBar(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: _isFirstCard 
                          ? Offset.zero
                          : _flyInAnimation.value * MediaQuery.of(context).size.height / 2,
                        child: _buildCard(),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _showFrontSide ? 
                      (_flipCardButtonEnabled ? _flipCard : null) : 
                      (_nextCardButtonEnabled ? _nextCard : null),
                    child: Text(
                      _showFrontSide ? 'Flip Card' : 
                      (_currentCardIndex == _randomizedCards.length - 1 ? 'End Session' : 'Next Card'),
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      minimumSize: Size(200, 60),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}