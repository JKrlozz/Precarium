import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioService;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playerStateSub;

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isShuffled = false;
  PlayerRepeatMode _repeatMode = PlayerRepeatMode.off;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  PlayerProvider(this._audioService);

  Song? get currentSong => _currentSong;
  List<Song> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isShuffled => _isShuffled;
  PlayerRepeatMode get repeatMode => _repeatMode;
  Duration get position => _position;
  Duration get duration => _duration;
  double get progress => _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds
      : 0.0;
  AudioPlayerService get audioService => _audioService;

  List<Song> get displayQueue {
    if (!_isShuffled) return List.unmodifiable(_queue);
    return _audioService.displayQueue;
  }

  int get displayIndex {
    if (!_isShuffled) return _currentIndex;
    return _audioService.displayIndex;
  }

  Future<void> init() async {
    await _audioService.init();
    _audioService.onSongChanged = _syncFromService;

    _positionSub = _audioService.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _durationSub = _audioService.durationStream.listen((dur) {
      if (dur != null) _duration = dur;
      notifyListeners();
    });

    _playerStateSub = _audioService.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    _currentSong = song;
    if (queue != null) {
      _queue = queue;
      _currentIndex = queue.indexOf(song);
    }
    _isPlaying = true;
    notifyListeners();
    await _audioService.playSong(song, queue: queue);
  }

  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    _queue = List.from(songs);
    _currentIndex = startIndex.clamp(0, songs.length - 1);
    if (songs.isNotEmpty) {
      _currentSong = songs[_currentIndex];
      _isPlaying = true;
    }
    notifyListeners();
    await _audioService.playQueue(songs, startIndex: startIndex);
  }

  Future<void> addToQueue(Song song) async {
    _queue.add(song);
    if (_currentSong == null && _queue.isNotEmpty) {
      await playQueue(_queue);
    } else {
      notifyListeners();
    }
  }

  void removeFromQueue(int index) {
    if (_isShuffled) {
      final realIndex = _audioService.displayQueue.length > index
          ? _queue.indexOf(_audioService.displayQueue[index])
          : -1;
      if (realIndex < 0) return;
      index = realIndex;
    }
    if (index < 0 || index >= _queue.length) return;
    _audioService.removeFromQueue(index);
    _queue.removeAt(index);
    if (_queue.isEmpty) {
      clearQueue();
    } else {
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex) {
        _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
        _currentSong = _queue.isNotEmpty ? _queue[_currentIndex] : null;
      }
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    await _audioService.togglePlayPause();
    _isPlaying = _audioService.isPlaying;
    notifyListeners();
  }

  Future<void> play() async {
    await _audioService.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> pause() async {
    await _audioService.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> next() async {
    await _audioService.next();
    _syncFromService();
  }

  Future<void> previous() async {
    await _audioService.previous();
    _syncFromService();
  }

  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
    _position = position;
    notifyListeners();
  }

  Future<void> seekToIndex(int index) async {
    final targetIndex = _isShuffled && _audioService.displayQueue.length > index
        ? _queue.indexOf(_audioService.displayQueue[index])
        : index;
    await _audioService.seekToIndex(targetIndex >= 0 ? targetIndex : index);
    _syncFromService();
  }

  void toggleShuffle() {
    _audioService.toggleShuffle();
    _isShuffled = _audioService.isShuffled;
    notifyListeners();
  }

  void cycleRepeatMode() {
    _audioService.cycleRepeatMode();
    _repeatMode = _audioService.repeatMode;
    notifyListeners();
  }

  void _syncFromService() {
    _currentSong = _audioService.currentSong;
    _currentIndex = _audioService.currentIndex;
    _position = _audioService.position;
    _isPlaying = _audioService.isPlaying;
    notifyListeners();
  }

  void clearQueue() {
    _audioService.clearQueue();
    _queue.clear();
    _currentSong = null;
    _currentIndex = -1;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
