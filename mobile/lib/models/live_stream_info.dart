class LiveStreamInfo {
  const LiveStreamInfo({
    required this.active,
    this.source,
  });

  final bool active;
  final String? source;

  factory LiveStreamInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LiveStreamInfo(active: false);
    return LiveStreamInfo(
      active: json['active'] as bool? ?? false,
      source: json['source'] as String?,
    );
  }

  bool get isScreen => source == 'screen';
  bool get isCamera => source == 'camera';
}
