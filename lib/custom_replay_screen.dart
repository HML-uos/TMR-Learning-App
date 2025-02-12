import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';
import 'dart:async';
import 'custom_deck.dart';
import 'utils.dart';
import 'package:wakelock_plus/wakelock_plus.dart';


class CustomReplayScreen extends StatefulWidget {
  final CustomDeck deck;

  const CustomReplayScreen({
    super.key,
    required this.deck,
  });

  @override
  State<CustomReplayScreen> createState() => _CustomReplayScreenState();
}

class _CustomReplayScreenState extends State<CustomReplayScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  int _countdown = 15 * 60;
  final int _repetitions = 10;
  final int _interval = 10;
  late int _remainingPlaybackTime;
  int _initialDelay = 15 * 60;
  bool _isPaused = false;
  int _pauseCountdown = 0;
  Timer? _pauseTimer;
  Timer? _timer;
  double _currentVolume = 100;
  Timer? _nextSoundTimer;
  bool _sessionCompleted = false;
  final List<int> _delayStack = [];
  final List<int> _pauseStack = [];
  late List<CustomCard> _replayCards;
  
  // Sound check specific variables
  bool _isSoundCheckActive = false;
  int _soundCheckCounter = 0;
  int _soundCheckCountdown = 60;
  int _nextSoundCountdown = 10;
  List<String> _soundFiles = [];

  bool get _canUndoDelay => _delayStack.isNotEmpty && _countdown >= 900;
  bool get _canUndoPause => _pauseStack.isNotEmpty && _pauseCountdown >= 900;

  void _initializeReplay() {
  // Filter cards if half replay mode is enabled
  _replayCards = widget.deck.halfReplayMode 
    ? widget.deck.cards.where((card) => card.selectedForReplay).toList()
    : List.from(widget.deck.cards);
  _replayCards.shuffle(Random());
  
  // Update timing calculations
  _remainingPlaybackTime = _replayCards.length * _repetitions * _interval;
}


  @override
  void initState() {
    super.initState();
    _initializeSoundCheck();
    _loadVolume();
    _initializeReplay();
  }



  void _initializeSoundCheck() {
  _soundFiles = [
    'soundcheck1_normalized.wav',
    'soundcheck2_normalized.wav',
    'soundcheck3_normalized.wav',
    'soundcheck4_normalized.wav',
    'soundcheck5_normalized.wav',
    'soundcheck6_normalized.wav'
  ];
}

  void _showHelpDialog() {
    Utils.showHelpDialog(
      context,
      'Replay Mode',
      '1. First, check your volume:\n'
      '   • Click "Volume Check"\n'
      '   • The Volume Check plays 6 sounds not associated with your flashcards for you to find a suitable volume for the nightly replay.\n'
      '   • Sounds already play only at 10% of their original volume during replay and volume check.\n'
      '2. Start replay:\n'
      '   • Click "Start Replay"\n'
      '   • There\'s a 15-minute delay before sounds start for you to fall asleep in peace\n'
      '   • You can add more delay time if needed and undo those delay elongations \n'
      '   • You can pause the replay for 15 minutes anytime if you wake up, you can add more pause time if needed and undo those pause elongations. \n'
      '   • During Replay all sounds from the deck get replayed 10 times with 10 second intervals between them. The order of replay sounds is randomized. If "Half Replay Mode" is active only half of all sounds are replayed.\n\n'
      'Important: Keep your screen on during the replay session.',
    );
  }

  Future<void> _loadVolume() async {
    double volume = await Utils.getReplayVolume();
    setState(() {
      _currentVolume = volume * 100;
    });
  }

  void _startDecrementingTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
          } else if (_remainingPlaybackTime > 0) {
            // Handled in _playSounds
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  void _startPauseTimer() {
    _pauseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_pauseCountdown > 0) {
          _pauseCountdown--;
        } else {
          _pauseTimer?.cancel();
          _isPaused = false;
          _startDecrementingTimer();
        }
      });
    });
  }

  void _updateVolume(double newVolume) {
    setState(() {
      _currentVolume = newVolume;
    });
    _audioPlayer.setVolume((newVolume / 100) * 0.1);
    Utils.setReplayVolume(newVolume / 100);
  }

  void _performSoundCheck() async {
    await WakelockPlus.enable();
    setState(() {
      _isSoundCheckActive = true;
      _soundCheckCounter = 0;
      _soundCheckCountdown = 60;
      _nextSoundCountdown = 10;
    });

    for (var sound in _soundFiles) {
      if (!_isSoundCheckActive) break;
      await _audioPlayer.play(AssetSource(sound));
      _audioPlayer.setVolume(_currentVolume / 100 * 0.1);

      for (int i = 0; i < 10; i++) {
        if (!_isSoundCheckActive) break;
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _soundCheckCountdown--;
          _nextSoundCountdown--;
        });
      }

      _soundCheckCounter++;
      setState(() {
        _nextSoundCountdown = 10;
      });
    }

    if (_isSoundCheckActive) {
      _endSoundCheck();
    }
  }

  void _endSoundCheck() {
    setState(() {
      _isSoundCheckActive = false;
    });
  }

  void _playSounds() async {
  await WakelockPlus.enable();
  setState(() {
    _audioPlayer.setVolume(_currentVolume / 100 * 0.1);
    _isPlaying = true;
    _countdown = _initialDelay;
    _isPaused = false;
    _pauseCountdown = 0;
    _remainingPlaybackTime = _replayCards.length * _repetitions * _interval;
  });
  _startDecrementingTimer();

  while (_countdown > 0) {
    await Future.delayed(const Duration(seconds: 1));
    if (_isPaused) return;
  }

  _remainingPlaybackTime = _replayCards.length * _repetitions * _interval;
  int currentRepetition = 0;
  int soundIndex = 0;

  while (_remainingPlaybackTime > 0) {
    if (_isPaused) {
      await Future.doWhile(() =>
          Future.delayed(const Duration(milliseconds: 100))
              .then((_) => _isPaused));
      continue;
    }

    CustomCard card = _replayCards[soundIndex];
    _audioPlayer.play(AssetSource(card.soundFile));

    for (int j = 0; j < _interval; j++) {
      if (_isPaused) break;
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        if (_remainingPlaybackTime > 0) {
          _remainingPlaybackTime--;
        }
      });
    }

    soundIndex++;
    if (soundIndex >= _replayCards.length) {
      soundIndex = 0;
      currentRepetition++;
      if (currentRepetition % 6 == 0) { // Reshuffle every 6th repetition (~ every 10 minutes)
        _replayCards.shuffle(Random());
      }
    }
  }

  setState(() {
    _isPlaying = false;
    _sessionCompleted = true;
  });
  
  await WakelockPlus.disable();
}

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _pauseCountdown = 15 * 60;
        _startPauseTimer();
      } else {
        _pauseTimer?.cancel();
        // Round down to nearest 10 seconds
        _remainingPlaybackTime = (_remainingPlaybackTime ~/ 10) * 10;
        _startDecrementingTimer();
      }
    });
  }

  void _addPauseTime() {
    setState(() {
      _pauseCountdown += 900;
      _pauseStack.add(900);
    });
  }

  void _undoPause() {
    if (_pauseStack.isNotEmpty) {
      setState(() {
        int lastPause = _pauseStack.removeLast();
        _pauseCountdown -= lastPause;
      });
    }
  }

  void _addDelay() {
    setState(() {
      _initialDelay += 900;
      _countdown += 900;
      _delayStack.add(900);
    });
  }

  void _undoDelay() {
    if (_delayStack.isNotEmpty) {
      setState(() {
        int lastDelay = _delayStack.removeLast();
        _initialDelay -= lastDelay;
        _countdown -= lastDelay;
      });
    }
  }

  String _formatTime(int timeInSeconds) {
    int hours = timeInSeconds ~/ 3600;
    int minutes = (timeInSeconds % 3600) ~/ 60;
    int seconds = timeInSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildSoundCheckUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Volume Check',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Session time remaining:',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        Text(
          _formatTime(_soundCheckCountdown),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Adjust the volume to a comfortable level',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Text(
                  'Next sound in:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                Text(
                  _formatTime(_nextSoundCountdown),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                Text(
                  'Remaining:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                Text(
                  '${5 - _soundCheckCounter} sound(s)',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 30),
        ElevatedButton(
          onPressed: _endSoundCheck,
          child: Text('Continue to Replay'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: Size(200, 60),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _performSoundCheck,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volume_up, color: Colors.black),
              SizedBox(width: 8),
              Text('Volume Check'),
            ],
          ),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: Size(200, 60),
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: _playSounds,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.nightlight_round, color: Colors.black),
              SizedBox(width: 8),
              Text('Start Replay'),
            ],
          ),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: Size(200, 60),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackUI() {
    if (!_isPlaying && _sessionCompleted) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.secondary,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline ,
              color: Theme.of(context).colorScheme.secondary,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Replay Session Completed',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Text(
          _countdown > 0 ? 'Sounds playing in:' : 'Remaining replay time:',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 20,
          ),
        ),
        Text(
          _formatTime(_countdown > 0 ? _countdown : _remainingPlaybackTime),
          style: TextStyle(
            color: _isPaused
                ? Colors.grey
                : Theme.of(context).colorScheme.onBackground,
            fontSize: 64,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_isPaused)
          Text(
            'Pause: ${_formatTime(_pauseCountdown)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        SizedBox(height: 20),
        if (_countdown > 0) ...[
          ElevatedButton(
            onPressed: _addDelay,
            child: Text('Add 15 Minutes', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              minimumSize: Size(200, 60),
            ),
          ),
          if (_canUndoDelay)
            ElevatedButton(
              onPressed: _undoDelay,
              child: Icon(Icons.undo, size: 30, color: Colors.black),
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(16),
              ),
            ),
         ] else if (_isPaused) ...[
          ElevatedButton(
            onPressed: _addPauseTime,
            child: Text('Add 15 Minutes', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              minimumSize: Size(200, 60),
            ),
          ),
          if (_canUndoPause)
          ElevatedButton(
            onPressed: _undoPause,
            child: Icon(Icons.undo, size: 30, color: Colors.black),
            style: ElevatedButton.styleFrom(
              shape: CircleBorder(),
              padding: EdgeInsets.all(16),
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ] else
          ElevatedButton(
            onPressed: _togglePause,
            child: Text('Pause for 15 Minutes', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              minimumSize: Size(200, 60),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isPlaying) {
          bool confirm = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('End Session?', style: TextStyle(color: Colors.black)),
              content: Text('Are you sure you want to end the replay session?',
                  style: TextStyle(color: Colors.black)),
              actions: [
                TextButton(
                  child: Text('No', style: TextStyle(color: Colors.black)),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text('Yes', style: TextStyle(color: Colors.black)),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ) ?? false;
          if (confirm) {
            await WakelockPlus.disable();
          }
          return confirm;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.deck.name} Replay'),
          backgroundColor: Theme.of(context).colorScheme.background,
          foregroundColor: Theme.of(context).colorScheme.onBackground,
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
              child: Text(
                'Do not deactivate your phone\'s screen during replay.\n'
                'Replay only works while the screen is active.\n'
                'The app automatically keeps the phone\'s screen active.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (_isPlaying || _isSoundCheckActive)
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
                        value: _currentVolume,
                        min: 0.0,
                        max: 100.0,
                        divisions: 100,
                        label: _currentVolume.round().toString(),
                        onChanged: _updateVolume,
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
            Expanded(
              child: Center(
                child: _isSoundCheckActive
                    ? _buildSoundCheckUI()
                    : !_isPlaying && !_sessionCompleted
                        ? _buildInitialUI()
                        : _buildPlaybackUI(),
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
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pauseTimer?.cancel();
    _nextSoundTimer?.cancel();
    _audioPlayer.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}