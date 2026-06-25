import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/video_player_config.dart';
import '../../../core/providers/app_providers.dart';
import '../../../models/playback_state.dart';
import '../../room/providers/room_provider.dart';

class PlayerControllerState {
  const PlayerControllerState({
    this.isReady = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.playbackRate = 1.0,
    this.error,
  });

  final bool isReady;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final double playbackRate;
  final String? error;

  PlayerControllerState copyWith({
    bool? isReady,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    double? playbackRate,
    String? error,
  }) {
    return PlayerControllerState(
      isReady: isReady ?? this.isReady,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackRate: playbackRate ?? this.playbackRate,
      error: error,
    );
  }
}

class PlayerControllerNotifier extends StateNotifier<PlayerControllerState> {
  PlayerControllerNotifier(this._ref) : super(const PlayerControllerState()) {
    _player = Player();
    _videoController = VideoController(
      _player,
      configuration: videoControllerConfiguration,
    );
    _subscriptions.add(_player.stream.position.listen((position) {
      if (!_applyingRemoteSync) {
        state = state.copyWith(position: position);
      }
    }));
    _subscriptions.add(_player.stream.duration.listen((duration) {
      state = state.copyWith(duration: duration);
    }));
    _subscriptions.add(_player.stream.playing.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    }));
    _subscriptions.add(_player.stream.rate.listen((rate) {
      state = state.copyWith(playbackRate: rate);
    }));

    _ref.listen<PlaybackState?>(playbackStateProvider, (prev, next) {
      if (next != null && prev != next) {
        _applyRemotePlayback(next);
      }
    });

    _startDriftCorrection();
  }

  final Ref _ref;
  late final Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _driftTimer;
  bool _applyingRemoteSync = false;
  String? _loadedUrl;
  int _loadedVersion = 0;
  int _loadGeneration = 0;

  Player get player => _player;
  VideoController get videoController => _videoController;

  Future<void> loadVideo(String url, {required int videoVersion}) async {
    if (_loadedUrl == url &&
        _loadedVersion == videoVersion &&
        videoVersion > 0 &&
        state.isReady) {
      return;
    }

    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _player.pause();
      await _player.open(Media(url), play: false);
      if (generation != _loadGeneration) return;

      _loadedUrl = url;
      _loadedVersion = videoVersion;
      state = state.copyWith(
        isReady: true,
        isLoading: false,
        position: Duration.zero,
        isPlaying: false,
      );

      if (!_ref.read(isHostProvider)) {
        final remote = _ref.read(playbackStateProvider);
        if (remote != null) {
          await _applyRemotePlayback(remote);
        }
      }
    } catch (e) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(isLoading: false, isReady: false, error: e.toString());
    }
  }

  Future<void> hostPlay() async {
    final time = _player.state.position.inMilliseconds / 1000.0;
    final rate = _player.state.rate;
    _ref.read(socketServiceProvider).syncPlay(time: time, rate: rate);
    await _player.play();
  }

  Future<void> hostPause() async {
    final time = _player.state.position.inMilliseconds / 1000.0;
    _ref.read(socketServiceProvider).syncPause(time: time);
    await _player.pause();
  }

  Future<void> hostSeek(double seconds) async {
    _ref.read(socketServiceProvider).syncSeek(time: seconds);
    await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  Future<void> hostSetRate(double rate) async {
    final time = _player.state.position.inMilliseconds / 1000.0;
    _ref.read(socketServiceProvider).syncRate(rate: rate, time: time);
    await _player.setRate(rate);
  }

  Future<void> _applyRemotePlayback(PlaybackState remote) async {
    final isHost = _ref.read(isHostProvider);
    if (isHost || !state.isReady) return;

    _applyingRemoteSync = true;
    try {
      final targetSec = remote.authoritativeTime();
      final localSec = _player.state.position.inMilliseconds / 1000.0;
      final driftMs = ((localSec - targetSec) * 1000).abs();

      if (driftMs > AppConfig.driftThresholdMs) {
        await _player.seek(
          Duration(milliseconds: (targetSec * 1000).round()),
        );
      }

      if (remote.playbackRate != _player.state.rate) {
        await _player.setRate(remote.playbackRate);
      }

      if (remote.isPlaying && !_player.state.playing) {
        await _player.play();
      } else if (!remote.isPlaying && _player.state.playing) {
        await _player.pause();
      }
    } finally {
      _applyingRemoteSync = false;
    }
  }

  void _startDriftCorrection() {
    _driftTimer = Timer.periodic(AppConfig.driftCheckInterval, (_) async {
      final isHost = _ref.read(isHostProvider);
      if (isHost || !state.isReady) return;

      final remote = _ref.read(playbackStateProvider);
      if (remote == null) return;

      final targetSec = remote.authoritativeTime();
      final localSec = _player.state.position.inMilliseconds / 1000.0;
      final driftMs = ((localSec - targetSec) * 1000).abs();

      if (driftMs > AppConfig.driftThresholdMs) {
        await _applyRemotePlayback(remote);
      }
    });
  }

  @override
  void dispose() {
    _driftTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}

final playerControllerProvider =
    StateNotifierProvider.autoDispose<PlayerControllerNotifier, PlayerControllerState>(
  (ref) => PlayerControllerNotifier(ref),
);
