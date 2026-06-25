import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/time_utils.dart';
import '../../../models/playback_state.dart';
import '../../../models/room_state.dart';
import '../../room/providers/room_provider.dart';
import '../providers/player_provider.dart';
import 'host_controls.dart';

class VideoPlayerWidget extends ConsumerStatefulWidget {
  const VideoPlayerWidget({super.key});

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_maybeLoadVideo);
  }

  void _maybeLoadVideo() {
    final room = ref.read(roomSessionProvider).roomState;
    final playUrl = _playUrl(room);
    if (playUrl != null && playUrl.isNotEmpty) {
      ref.read(playerControllerProvider.notifier).loadVideo(
            playUrl,
            videoVersion: room?.videoVersion ?? 0,
          );
    }
  }

  String? _resolvedVideoUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return ref.read(apiServiceProvider).resolveVideoUrl(url);
  }

  String? _playUrl(RoomState? room) {
    final base = _resolvedVideoUrl(room?.videoUrl);
    if (base == null || base.isEmpty) return null;
    return ref.read(apiServiceProvider).videoUrlWithVersion(
          base,
          room?.videoVersion ?? 0,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(roomSessionProvider, (prev, next) {
      final prevRoom = prev?.roomState;
      final nextRoom = next.roomState;
      final prevVersion = prevRoom?.videoVersion ?? 0;
      final nextVersion = nextRoom?.videoVersion ?? 0;
      final playUrl = _playUrl(nextRoom);

      if (playUrl != null &&
          playUrl.isNotEmpty &&
          (nextVersion != prevVersion || _playUrl(prevRoom) != playUrl)) {
        ref.read(playerControllerProvider.notifier).loadVideo(
              playUrl,
              videoVersion: nextVersion,
            );
      }
    });

    final room = ref.watch(roomSessionProvider).roomState;
    final playerState = ref.watch(playerControllerProvider);
    final isHost = room?.isHost ?? false;

    if (room == null) {
      return const Center(child: Text('Connecting...'));
    }

    if (!room.hasVideo || room.videoUrl == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_outlined, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              isHost ? 'Upload a video to start' : 'Waiting for host to add a video',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    final notifier = ref.read(playerControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Video(
                    controller: notifier.videoController,
                    controls: NoVideoControls,
                    fit: BoxFit.contain,
                    fill: Colors.black,
                  ),
                  if (playerState.isLoading)
                    const ColoredBox(
                      color: Colors.black54,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (playerState.error != null)
                    ColoredBox(
                      color: Colors.black87,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Player error: ${playerState.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (isHost)
            HostControls(
              position: playerState.position,
              duration: playerState.duration,
              isPlaying: playerState.isPlaying,
              playbackRate: playerState.playbackRate,
              onPlay: notifier.hostPlay,
              onPause: notifier.hostPause,
              onSeek: notifier.hostSeek,
              onRateChanged: notifier.hostSetRate,
            )
          else
            _ParticipantStatus(
              position: playerState.position,
              duration: playerState.duration,
              playbackState: room.playbackState,
            ),
        ],
      ),
    );
  }
}

class _ParticipantStatus extends StatelessWidget {
  const _ParticipantStatus({
    required this.position,
    required this.duration,
    required this.playbackState,
  });

  final Duration position;
  final Duration duration;
  final PlaybackState playbackState;

  @override
  Widget build(BuildContext context) {
    final posSec = position.inMilliseconds / 1000.0;
    final durSec = duration.inMilliseconds / 1000.0;

    return Row(
      children: [
        Icon(
          playbackState.isPlaying ? Icons.play_arrow : Icons.pause,
          size: 18,
          color: Colors.white54,
        ),
        const SizedBox(width: 8),
        Text(
          '${TimeUtils.formatDuration(posSec)} / ${TimeUtils.formatDuration(durSec)}',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const Spacer(),
        Text(
          'Synced with host',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
