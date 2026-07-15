import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

enum PlayerRepeatMode { off, all, one }

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isShuffled = false;
  PlayerRepeatMode _repeatMode = PlayerRepeatMode.off;

  List<int> _shuffleOrder = [];
  int _shuffleIndex = 0;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<double> get speedStream => _player.speedStream;
  Stream<SequenceState?> get sequenceStream => _player.sequenceStateStream;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get isShuffled => _isShuffled;
  PlayerRepeatMode get repeatMode => _repeatMode;
  int get currentIndex => _currentIndex;
  Song? get currentSong {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      return _queue[_currentIndex];
    }
    return null;
  }

  Future<void> init() async {
    _player.playbackEventStream.listen(_onPlaybackEvent);
  }

  void _onPlaybackEvent(PlaybackEvent event) {
    _player.positionStream.listen((_) {});
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    if (queue != null) {
      _queue = queue;
      _currentIndex = queue.indexOf(song);
      _buildShuffleOrder();
    } else {
      final index = _queue.indexOf(song);
      if (index >= 0) _currentIndex = index;
    }

    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      await _playAtIndex(_currentIndex);
    }
  }

  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    _queue = List.from(songs);
    _currentIndex = startIndex.clamp(0, songs.length - 1);
    _buildShuffleOrder();
    if (_queue.isNotEmpty) {
      await _playAtIndex(_currentIndex);
    }
  }

  Future<void> _playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    final song = _queue[index];
    try {
      await _player.setFilePath(song.filePath);
      await _player.play();
    } catch (e) {
      // Error playing file
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> play() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;

    if (_isShuffled) {
      _shuffleIndex = (_shuffleIndex + 1) % _shuffleOrder.length;
      await _playAtIndex(_shuffleOrder[_shuffleIndex]);
    } else {
      final nextIndex = _currentIndex + 1;
      if (nextIndex >= _queue.length) {
        if (_repeatMode == PlayerRepeatMode.all) {
          await _playAtIndex(0);
        } else {
          await _player.pause();
          await _player.seek(Duration.zero);
        }
      } else {
        await _playAtIndex(nextIndex);
      }
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;

    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_isShuffled) {
      _shuffleIndex = (_shuffleIndex - 1 + _shuffleOrder.length) % _shuffleOrder.length;
      await _playAtIndex(_shuffleOrder[_shuffleIndex]);
    } else {
      final prevIndex = _currentIndex - 1;
      if (prevIndex < 0) {
        if (_repeatMode == PlayerRepeatMode.all) {
          await _playAtIndex(_queue.length - 1);
        } else {
          await _player.seek(Duration.zero);
        }
      } else {
        await _playAtIndex(prevIndex);
      }
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> seekToIndex(int index) async {
    if (index >= 0 && index < _queue.length) {
      await _playAtIndex(index);
    }
  }

  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    if (_isShuffled) {
      _buildShuffleOrder();
    }
  }

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case PlayerRepeatMode.off:
        _repeatMode = PlayerRepeatMode.all;
      case PlayerRepeatMode.all:
        _repeatMode = PlayerRepeatMode.one;
      case PlayerRepeatMode.one:
        _repeatMode = PlayerRepeatMode.off;
    }
    _player.setLoopMode(_getLoopMode());
  }

  LoopMode _getLoopMode() {
    switch (_repeatMode) {
      case PlayerRepeatMode.off:
        return LoopMode.off;
      case PlayerRepeatMode.all:
        return LoopMode.all;
      case PlayerRepeatMode.one:
        return LoopMode.one;
    }
  }

  void _buildShuffleOrder() {
    _shuffleOrder = List.generate(_queue.length, (i) => i);
    _shuffleOrder.shuffle();
    if (_currentIndex >= 0) {
      _shuffleOrder.remove(_currentIndex);
      _shuffleOrder.insert(0, _currentIndex);
    }
    _shuffleIndex = 0;
  }

  void clearQueue() {
    _queue.clear();
    _currentIndex = -1;
    _shuffleOrder.clear();
    _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
