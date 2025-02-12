import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'utils.dart';
import 'dart:async';

class AmbientTMRScreen extends StatefulWidget {
  const AmbientTMRScreen({super.key});

  @override
  State<AmbientTMRScreen> createState() => _AmbientTMRScreenState();
}

Map<String, Duration> _soundDurations = {
  'BirdAmbience.wav': Duration(minutes: 3, seconds: 5),
  'CaveAmbience.wav': Duration(minutes: 2, seconds: 8),
  'WaterfallAmbience.wav': Duration(minutes: 2),
};

class _AmbientTMRScreenState extends State<AmbientTMRScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _selectedSound = 'CaveAmbience.wav';
  bool _isPlaying = false;
  bool _isReplaying = false;
  int _countdown = 15 * 60;
  int _replayCount = 0;
  Timer? _timer;
  double _currentVolume = 100;
  bool _isPaused = false;
  int _pauseCountdown = 0;
  Timer? _pauseTimer;
  bool _isSoundCheckActive = false;
  int _actualDelay = 0;

  @override
  void initState() {
    super.initState();
    _loadVolume();
  }

  Future<void> _loadVolume() async {
    double volume = await Utils.getReplayVolume();
    setState(() {
      _currentVolume = volume * 100;
    });
  }

  void _updateVolume(double newVolume) {
    setState(() {
      _currentVolume = newVolume;
    });
    _audioPlayer.setVolume((newVolume / 100) * 0.1);
    Utils.setReplayVolume(newVolume / 100);
  }

  void _startAmbience() async {
    if (_isPlaying || _isReplaying) return;
    
    try {
        // First release any existing resources
        await _audioPlayer.stop();
        await _audioPlayer.release();
        
        // Set up the audio player
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.setVolume(_currentVolume / 100);
        await _audioPlayer.setSource(AssetSource(_selectedSound));
        
        setState(() {
            _isPlaying = true;
        });
        
        // Start playing after state is updated
        await _audioPlayer.resume();
        
        // Try to enable wakelock, but don't throw if it fails (web)
        try {
            await WakelockPlus.enable();
        } catch (e) {
            print('Wakelock not available: $e');
        }
    } catch (e) {
        print('Error playing sound: $e');
        _stopAmbience();
    }
}

  void _stopAmbience() async {
    _audioPlayer.stop();
    await WakelockPlus.disable();
    setState(() {
      _isPlaying = false;
    });
  }

  void _startReplay() async {
    if (_isPlaying || _isReplaying) return;
    await WakelockPlus.enable();
    setState(() {
      _isReplaying = true;
      _replayCount = 0;
      _isPaused = false;
    });
    _startDecrementingTimer();
  }

  void _startDecrementingTimer() {
  _timer?.cancel();
  _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (!_isPaused) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
          if (_countdown == 0) {
            _startReplaySequence();
          }
        }
      });
    }
  });
}

void _startReplaySequence() async {
  if (_actualDelay > 0) {
    await Future.delayed(Duration(seconds: _actualDelay));
    _actualDelay = 0;  // Reset after delay is done
  }
  _audioPlayer.setReleaseMode(ReleaseMode.loop);
  for (int i = 0; i < 20; i++) {
    if (!_isReplaying) break;
    
    _audioPlayer.setVolume(_currentVolume / 100 * 0.1);
    await _audioPlayer.play(AssetSource(_selectedSound));
    
    // Wait for the duration, but check pause state every 100ms
    int durationInMs = _soundDurations[_selectedSound]!.inMilliseconds;
    int elapsed = 0;
    while (elapsed < durationInMs) {
      if (_isPaused) {
        await _audioPlayer.pause();
        // Wait while paused
        await Future.doWhile(() => 
          Future.delayed(const Duration(milliseconds: 100))
            .then((_) => _isPaused)
        );
        // Resume playback if we're still in replay mode
        if (_isReplaying) {
          await _audioPlayer.resume();
        }
      }
      await Future.delayed(const Duration(milliseconds: 100));
      elapsed += 100;
      if (!_isReplaying) break;
    }
    
    if (_isReplaying) {
      setState(() {
        _replayCount++;
      });
    }
  }
  _endReplay();
}

  void _endReplay() {
    _timer?.cancel();
    _audioPlayer.stop();
    WakelockPlus.disable();
    setState(() {
      _isReplaying = false;
      _replayCount = 0;
    });
  }


  void _togglePause() {
  setState(() {
    _isPaused = !_isPaused;
    if (_isPaused) {
      _pauseCountdown = 15 * 60;
      _startPauseTimer();
    } else {
      _pauseTimer?.cancel();
      _startDecrementingTimer();
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

  void _performSoundCheck() async {
    if (_isPlaying || _isReplaying) return;
    await WakelockPlus.enable();
    setState(() {
      _isSoundCheckActive = true;
    });
    _audioPlayer.setVolume(_currentVolume / 100 * 0.1);
    await _audioPlayer.play(AssetSource(_selectedSound));
  }

  void _endSoundCheck() {
    _audioPlayer.stop();
    setState(() {
      _isSoundCheckActive = false;
    });
  }

  String _formatTime(int timeInSeconds) {
    int hours = timeInSeconds ~/ 3600;
    int minutes = (timeInSeconds % 3600) ~/ 60;
    int seconds = timeInSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showHelpDialog() {
  Utils.showHelpDialog(
    context,
    'Ambient TMR Mode',
    '• Choose an ambient sound to play during learning from the three options up top\n'
    '• Use the volume slider to adjust to a comfortable level\n'
    '• Start ambient playback while studying\n\n'
    '• Sound Check and Replay function just like for the flashcards.\n'
    '• Sounds already play only at 10% of their original volume during replay and volume check.\n'
    '• There\'s a 15-minute delay before sounds start for you to fall asleep in peace\n'
    '• You can add more delay time if needed and undo those delay elongations \n'
    '• You can pause the replay for 15 minutes anytime if you wake up, you can add more pause time if needed and undo those pause elongations \n\n'
    '• Ambient sounds get replayed 20 times during replay with the sounds being 2 minutes (Cave & Waterfall) and 3 minutes long (Birds) for a total replay time of 40 minutes (Cave & Waterfall) and 1 hour (Birds). \n'
  );
}


  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Ambient TMR'),
      backgroundColor: Theme.of(context).colorScheme.background,
      foregroundColor: Theme.of(context).colorScheme.onBackground,
    ),
    body: Column(
      children: [
        // Warning Banner
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
          child: Text(
            'Experimental Feature, not as stable as Flashcard Learning! \n Ambience/Replay only plays while the phone\'s screen is active! \n Active Ambience/Replay keeps the screen active. \n Start Ambience sometimes has to be clicked several times before sound starts.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Volume Slider
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                Icons.volume_mute,
                color: Theme.of(context).colorScheme.onBackground,
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
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Sound Selection Section
                  Text(
                    'Sound Selection',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 8, bottom: 24),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildSoundButton(
                              'CaveAmbience.wav',
                              Icons.landscape,
                              'Cave Ambience',
                            ),
                            _buildSoundButton(
                              'WaterfallAmbience.wav',
                              Icons.water_drop,
                              'Waterfall Ambience',
                            ),
                            _buildSoundButton(
                              'BirdAmbience.wav',
                              Icons.forest,
                              'Bird Ambience',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Control Section
                  Text(
                    'Play / Replay',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isSoundCheckActive
                      ? _buildSoundCheckUI()
                      : _isReplaying
                        ? _buildReplayUI()
                        : _buildMainUI(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: Padding(
      padding: EdgeInsets.only(left: 32.0, bottom: 16.0),
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

  Widget _buildSoundButton(String soundFile, IconData icon, String label) {
    final isSelected = _selectedSound == soundFile;
    
    return GestureDetector(
      onTap: _isReplaying ? null : () {
        setState(() {
          _selectedSound = soundFile;
        });
      },
      child: Container(
        width: 100,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
              ? Theme.of(context).colorScheme.secondary
              : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected 
                ? Theme.of(context).colorScheme.secondary
                : Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected 
                  ? Theme.of(context).colorScheme.secondary
                  : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundCheckUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Sound Check Active',
          style: TextStyle(
            fontSize: 24,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Adjust volume to a comfortable level',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: _endSoundCheck,
          child: Text('End Sound Check'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: Size(200, 60),
          ),
        ),
      ],
    );
  }

  Widget _buildReplayUI() {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        _countdown > 0 ? 'Starting in:' : 'Replays remaining:',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onBackground,
          fontSize: 20,
        ),
      ),
      Text(
        _countdown > 0 ? _formatTime(_countdown) : '${20 - _replayCount}',
        style: TextStyle(
          color: _isPaused ? Colors.grey : Theme.of(context).colorScheme.onBackground,
          fontSize: 64,
          fontWeight: FontWeight.bold,
        ),
      ),
      if (_isPaused)
        Text(
          'Paused: ${_formatTime(_pauseCountdown)}',
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
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Colors.black,
          ),
        ),
        if (_canUndoDelay)
          ElevatedButton(
            onPressed: _undoDelay,
            child: Icon(Icons.undo, size: 30, color: Colors.black),
            style: ElevatedButton.styleFrom(
              shape: CircleBorder(),
              padding: EdgeInsets.all(16),
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          ),
      ] else if (_isPaused) ...[
        ElevatedButton(
          onPressed: _addPauseTime,
          child: Text('Add 15 Minutes', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: Size(200, 60),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Colors.black,
          ),
        ),
        ElevatedButton(
          onPressed: _togglePause,
          child: Text('Resume', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: Size(200, 60),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Colors.black,
          ),
        ),
      ] else
        ElevatedButton(
          onPressed: _togglePause,
          child: Text('Pause for 15 Minutes', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: Size(200, 60),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Colors.black,
          ),
        ),
    ],
  );
}

  final List<int> _delayStack = [];
bool get _canUndoDelay => _delayStack.isNotEmpty && _countdown >= 900;

void _addDelay() {
    setState(() {
        _countdown += 900;
        _actualDelay += 900;
        _delayStack.add(900);
    });
}

void _undoDelay() {
    if (_delayStack.isNotEmpty) {
        setState(() {
            int lastDelay = _delayStack.removeLast();
            _countdown -= lastDelay;
            _actualDelay -= lastDelay;
        });
    }
}

void _addPauseTime() {
  setState(() {
    _pauseCountdown += 900;
  });
}


  Widget _buildMainUI() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      Container(
        width: 100,
        height: 100,
        child: ElevatedButton(
          onPressed: _performSoundCheck,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(12),
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // This makes it square
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.volume_up, size: 32, color: Colors.black),
              SizedBox(height: 8),
              Text(
                'Volume Check',
                style: TextStyle(color: Colors.black, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      Container(
        width: 100,
        height: 100,
        child: ElevatedButton(
          onPressed: _isPlaying ? _stopAmbience : _startAmbience,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(12),
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // This makes it square
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isPlaying ? Icons.stop : Icons.play_arrow,
                size: 32,
                color: Colors.black,
              ),
              SizedBox(height: 8),
              Text(
                _isPlaying ? 'Stop\nAmbience' : 'Start\nAmbience',
                style: TextStyle(color: Colors.black, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      Container(
        width: 100,
        height: 100,
        child: ElevatedButton(
          onPressed: _startReplay,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(12),
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // This makes it square
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.replay, size: 32, color: Colors.black),
              SizedBox(height: 8),
              Text(
                'Start\nReplay',
                style: TextStyle(color: Colors.black, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

  @override
  void dispose() {
    _timer?.cancel();
    _pauseTimer?.cancel();
    _audioPlayer.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}
