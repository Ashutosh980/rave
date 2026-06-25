import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../live_stream/presentation/live_stream_view.dart';
import '../../live_stream/providers/live_stream_provider.dart';
import '../../player/presentation/video_player_widget.dart';

/// Shows live WebRTC video when active, otherwise the file player.
class RoomVideoArea extends ConsumerWidget {
  const RoomVideoArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveStreamProvider);

    if (live.showLiveVideo || live.isConnecting) {
      return const LiveStreamView();
    }

    return const VideoPlayerWidget();
  }
}
