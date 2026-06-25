import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../providers/live_stream_provider.dart';

class LiveStreamView extends ConsumerStatefulWidget {
  const LiveStreamView({super.key});

  @override
  ConsumerState<LiveStreamView> createState() => _LiveStreamViewState();
}

class _LiveStreamViewState extends ConsumerState<LiveStreamView> {
  final _renderer = RTCVideoRenderer();
  MediaStream? _attachedStream;

  @override
  void initState() {
    super.initState();
    _renderer.initialize();
  }

  @override
  void dispose() {
    _renderer.dispose();
    super.dispose();
  }

  void _attachStream(MediaStream? stream) {
    if (_attachedStream == stream) return;
    _attachedStream = stream;
    _renderer.srcObject = stream;
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(liveStreamProvider);
    final stream = live.localStream ?? live.remoteStream;

    ref.listen(liveStreamProvider, (prev, next) {
      final nextStream = next.localStream ?? next.remoteStream;
      _attachStream(nextStream);
    });

    _attachStream(stream);

    if (!live.showLiveVideo && !live.isConnecting) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (live.showLiveVideo)
          RTCVideoView(
            _renderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          )
        else
          const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, color: Colors.white, size: 8),
                const SizedBox(width: 6),
                Text(
                  live.role == LiveStreamRole.host ? 'LIVE' : 'WATCHING LIVE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
