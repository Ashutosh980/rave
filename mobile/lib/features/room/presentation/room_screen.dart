import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/server_config_provider.dart';

import '../../chat/presentation/chat_panel.dart';
import '../../player/presentation/video_player_widget.dart';
import '../providers/room_provider.dart';

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

  @override
  void dispose() {
    ref.read(roomSessionProvider.notifier).leaveRoom();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(roomSessionProvider);
    final room = session.roomState;

    return Scaffold(
      appBar: AppBar(
        title: Text('Room ${widget.roomId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareInvite,
            tooltip: 'Share room invite',
          ),
          if (room?.isHost == true)
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
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: session.isConnecting
          ? const Center(child: CircularProgressIndicator())
          : room == null
              ? const Center(child: Text('Not connected'))
              : Column(
                  children: [
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
                      child: VideoPlayerWidget(),
                    ),
                    const Expanded(
                      flex: 2,
                      child: ChatPanel(),
                    ),
                  ],
                ),
    );
  }
}
