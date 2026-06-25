import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/server_config_provider.dart';

import '../../chat/presentation/chat_panel.dart';
import '../../live_stream/providers/live_stream_provider.dart';
import '../../player/providers/player_provider.dart';
import '../providers/room_provider.dart';
import 'room_video_area.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({
    super.key,
    required this.roomId,
    required this.username,
    this.participantId,
  });

  final String roomId;
  final String username;
  final String? participantId;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_connect);
  }

  Future<void> _connect() async {
    try {
      await ref.read(roomSessionProvider.notifier).joinRoom(
            roomId: widget.roomId,
            username: widget.username,
            participantId: widget.participantId,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _pickAndUploadVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;

    try {
      await ref.read(roomSessionProvider.notifier).uploadVideo(
            File(result.files.single.path!),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _shareInvite() async {
    final serverUrl = ref.read(serverUrlProvider);
    final text = '''
Join my Rave watch party!

Room ID: ${widget.roomId}
Server: $serverUrl

1. Install Rave app
2. Set Server URL to the link above
3. Enter Room ID and your username
''';
    await SharePlus.instance.share(ShareParams(text: text, subject: 'Join Rave room ${widget.roomId}'));
  }

  void _exitRoom() {
    ref.read(liveStreamProvider.notifier).stopStream();
    ref.invalidate(liveStreamProvider);
    ref.invalidate(playerControllerProvider);
    ref.read(roomSessionProvider.notifier).leaveRoom();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showLiveStreamMenu() async {
    final live = ref.read(liveStreamProvider);
    if (live.isActive) {
      await ref.read(liveStreamProvider.notifier).stopStream();
      return;
    }

    final source = await showModalBottomSheet<LiveStreamSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, LiveStreamSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.screen_share),
              title: const Text('Screen share'),
              onTap: () => Navigator.pop(context, LiveStreamSource.screen),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      await ref.read(liveStreamProvider.notifier).startStream(source);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Live stream failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(roomSessionProvider);
    final room = session.roomState;

    ref.listen<String?>(
      roomSessionProvider.select((s) => s.error),
      (prev, next) {
        if (next == null || next == _lastShownError || !mounted) return;
        _lastShownError = next;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitRoom();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Room ${widget.roomId}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareInvite,
              tooltip: 'Share room invite',
            ),
            if (room?.isHost == true) ...[
              IconButton(
                icon: Icon(
                  ref.watch(liveStreamProvider).isActive
                      ? Icons.stop_circle_outlined
                      : Icons.videocam,
                  color: ref.watch(liveStreamProvider).isActive ? Colors.red : null,
                ),
                onPressed: _showLiveStreamMenu,
                tooltip: ref.watch(liveStreamProvider).isActive
                    ? 'Stop live stream'
                    : 'Start live stream',
              ),
              IconButton(
                icon: session.isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                onPressed: session.isUploading ? null : _pickAndUploadVideo,
                tooltip: 'Upload video',
              ),
            ],
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _exitRoom,
            ),
          ],
        ),
        body: session.isConnecting
            ? const Center(child: CircularProgressIndicator())
            : room == null
                ? const Center(child: Text('Not connected'))
                : Column(
                    children: [
                      if (session.error != null)
                        MaterialBanner(
                          content: Text(session.error!),
                          backgroundColor: Theme.of(context).colorScheme.errorContainer,
                          actions: [
                            TextButton(
                              onPressed: () {
                                ref.read(roomSessionProvider.notifier).clearError();
                              },
                              child: const Text('Dismiss'),
                            ),
                          ],
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text('${room.participantCount} watching'),
                            const Spacer(),
                            if (room.isHost)
                              const Chip(
                                label: Text('Host'),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ),
                      const Expanded(
                        flex: 3,
                        child: RoomVideoArea(),
                      ),
                      const Expanded(
                        flex: 2,
                        child: ChatPanel(),
                      ),
                    ],
                  ),
      ),
    );
  }
}
