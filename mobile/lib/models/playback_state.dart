class PlaybackState {
  const PlaybackState({
    required this.isPlaying,
    required this.currentTime,
    required this.playbackRate,
    required this.updatedAt,
  });

  final bool isPlaying;
  final double currentTime;
  final double playbackRate;
  final int updatedAt;

  factory PlaybackState.initial() {
    return const PlaybackState(
      isPlaying: false,
      currentTime: 0,
      playbackRate: 1,
      updatedAt: 0,
    );
  }

  factory PlaybackState.fromJson(Map<String, dynamic> json) {
    return PlaybackState(
      isPlaying: json['isPlaying'] as bool? ?? false,
      currentTime: (json['currentTime'] as num?)?.toDouble() ?? 0,
      playbackRate: (json['playbackRate'] as num?)?.toDouble() ?? 1,
      updatedAt: json['updatedAt'] as int? ?? 0,
    );
  }

  /// Computes server-authoritative position including elapsed play time.
  double authoritativeTime([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (!isPlaying) return currentTime;
    final elapsedSec = (now - updatedAt) / 1000;
    return currentTime + elapsedSec * playbackRate;
  }

  PlaybackState copyWith({
    bool? isPlaying,
    double? currentTime,
    double? playbackRate,
    int? updatedAt,
  }) {
    return PlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentTime: currentTime ?? this.currentTime,
      playbackRate: playbackRate ?? this.playbackRate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
