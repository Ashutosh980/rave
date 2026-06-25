import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/socket_events.dart';
import '../../../core/providers/app_providers.dart';
import '../../../models/chat_message.dart';
import '../../../models/participant.dart';
import '../../../models/playback_state.dart';
import '../../../models/room_state.dart';
import '../../../services/api_service.dart';
import '../../../services/socket_service.dart';

class RoomSessionState {
  const RoomSessionState({
    this.roomState,
    this.participantId,
    this.username,
    this.isConnecting = false,
    this.isUploading = false,
    this.error,
    this.messages = const [],
  });

  final RoomState? roomState;
  final String? participantId;
  final String? username;
  final bool isConnecting;
  final bool isUploading;
  final String? error;
  final List<ChatMessage> messages;

  bool get isConnected => roomState != null && participantId != null;

  RoomSessionState copyWith({
    RoomState? roomState,
    String? participantId,
    String? username,
    bool? isConnecting,
    bool? isUploading,
    String? error,
    List<ChatMessage>? messages,
    bool clearError = false,
  }) {
    return RoomSessionState(
      roomState: roomState ?? this.roomState,
      participantId: participantId ?? this.participantId,
      username: username ?? this.username,
      isConnecting: isConnecting ?? this.isConnecting,
      isUploading: isUploading ?? this.isUploading,
      error: clearError ? null : (error ?? this.error),
      messages: messages ?? this.messages,
    );
  }
}

class RoomSessionNotifier extends StateNotifier<RoomSessionState> {
  RoomSessionNotifier(this._api, this._socket) : super(const RoomSessionState());

  final ApiService _api;
  final SocketService _socket;
  bool _listenersRegistered = false;
  bool _hasJoinedOnce = false;

  Future<CreateRoomResponse> createRoom(String username) async {
    return _api.createRoom(username);
  }

  Future<void> joinRoom({
    required String roomId,
    required String username,
    String? participantId,
  }) async {
    state = state.copyWith(
      isConnecting: true,
      username: username,
      clearError: true,
    );

    try {
      await _api.getRoom(roomId);
      _socket.connect();
      _registerListeners();

      final ack = await _socket.joinRoom(
        roomId: roomId,
        username: username,
        participantId: participantId,
      );

      final roomStateJson = ack['roomState'] as Map<String, dynamic>?;
      final pid = ack['participantId'] as String?;

      if (roomStateJson == null || pid == null) {
        throw SocketException('Failed to join room');
      }

      final roomState = _roomStateFromJson(roomStateJson);

      state = state.copyWith(
        roomState: roomState,
        participantId: pid,
        messages: roomState.chatMessages,
        isConnecting: false,
        clearError: true,
      );
      _hasJoinedOnce = true;
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> uploadVideo(File file) async {
    final roomId = state.roomState?.roomId;
    if (roomId == null) return;

    state = state.copyWith(isUploading: true, clearError: true);

    try {
      // Verify room still exists on server before large upload
      await _api.getRoom(roomId);

      final participantId = state.participantId;
      if (participantId == null) {
        throw StateError('Not connected to room');
      }

      final upload = await _api.uploadVideo(
        roomId,
        file,
        participantId: participantId,
      );
      final resolved = _api.resolveVideoUrl(upload.videoUrl);

      state = state.copyWith(
        isUploading: false,
        roomState: state.roomState?.copyWith(
          hasVideo: true,
          videoUrl: resolved,
          videoVersion: upload.videoVersion,
          playbackState: upload.playbackState,
        ),
      );

      _socket.notifyVideoReady();
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      rethrow;
    }
  }

  void sendMessage(String content) {
    _socket.sendChatMessage(content);
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void leaveRoom() {
    final roomId = state.roomState?.roomId;
    if (roomId != null) {
      _socket.leaveRoom(roomId);
    }
    _teardownListeners();
    _hasJoinedOnce = false;
    state = const RoomSessionState();
  }

  void _registerListeners() {
    if (_listenersRegistered) return;
    _listenersRegistered = true;

    _socket.on(SocketEvents.roomState, _onRoomState);
    _socket.on(SocketEvents.participantJoined, _onParticipantJoined);
    _socket.on(SocketEvents.participantLeft, _onParticipantLeft);
    _socket.on(SocketEvents.participantOffline, _onParticipantOffline);
    _socket.on(SocketEvents.participantReconnected, _onParticipantReconnected);
    _socket.on(SocketEvents.hostChanged, _onHostChanged);
    _socket.on(SocketEvents.playbackUpdate, _onPlaybackUpdate);
    _socket.on(SocketEvents.chatMessage, _onChatMessage);
    _socket.on(SocketEvents.videoReady, _onVideoReady);
    _socket.on(SocketEvents.error, _onSocketError);
    _socket.onReconnect((_) => _onSocketReconnect());
  }

  void _teardownListeners() {
    if (!_listenersRegistered) return;
    _socket.off(SocketEvents.roomState);
    _socket.off(SocketEvents.participantLeft);
    _socket.off(SocketEvents.participantOffline);
    _socket.off(SocketEvents.participantJoined);
    _socket.off(SocketEvents.participantReconnected);
    _socket.off(SocketEvents.hostChanged);
    _socket.off(SocketEvents.playbackUpdate);
    _socket.off(SocketEvents.chatMessage);
    _socket.off(SocketEvents.videoReady);
    _socket.off(SocketEvents.error);
    _socket.offReconnect();
    _listenersRegistered = false;
  }

  Future<void> _onSocketReconnect() async {
    final roomId = state.roomState?.roomId;
    final username = state.username;
    final participantId = state.participantId;
    if (!_hasJoinedOnce || roomId == null || username == null || participantId == null) {
      return;
    }

    try {
      final ack = await _socket.joinRoom(
        roomId: roomId,
        username: username,
        participantId: participantId,
      );

      final roomStateJson = ack['roomState'] as Map<String, dynamic>?;
      if (roomStateJson == null) return;

      var roomState = _roomStateFromJson(roomStateJson);

      state = state.copyWith(
        roomState: roomState,
        participantId: ack['participantId'] as String? ?? participantId,
        messages: roomState.chatMessages,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: 'Reconnect failed: $e');
    }
  }

  RoomState _roomStateFromJson(Map<String, dynamic> json) {
    var roomState = RoomState.fromJson(json);
    if (roomState.videoUrl != null) {
      roomState = roomState.copyWith(
        videoUrl: _api.resolveVideoUrl(roomState.videoUrl),
      );
    }
    return roomState;
  }

  void _onRoomState(dynamic data) {
    if (data is! Map) return;
    final roomState = _roomStateFromJson(Map<String, dynamic>.from(data));
    state = state.copyWith(roomState: roomState, messages: roomState.chatMessages);
  }

  void _onParticipantJoined(dynamic data) {
    if (data is! Map || state.roomState == null) return;
    final participant = Participant.fromJson(
      Map<String, dynamic>.from(data['participant'] as Map),
    );
    if (state.roomState!.participants.any((p) => p.id == participant.id)) return;

    final updated = [...state.roomState!.participants, participant];
    final count = data['participantCount'] as int? ?? updated.length;
    state = state.copyWith(
      roomState: state.roomState!.copyWith(
        participants: updated,
        participantCount: count,
      ),
    );
  }

  void _onParticipantLeft(dynamic data) {
    if (data is! Map || state.roomState == null) return;
    final id = data['participantId'] as String;
    final updated = state.roomState!.participants.where((p) => p.id != id).toList();
    final count = data['participantCount'] as int? ?? updated.length;
    state = state.copyWith(
      roomState: state.roomState!.copyWith(
        participants: updated,
        participantCount: count,
      ),
    );
  }

  void _onParticipantOffline(dynamic data) {
    if (data is! Map || state.roomState == null) return;
    final id = data['participantId'] as String;
    final updated = state.roomState!.participants.where((p) => p.id != id).toList();
    final count = data['participantCount'] as int? ?? updated.length;
    state = state.copyWith(
      roomState: state.roomState!.copyWith(
        participants: updated,
        participantCount: count,
      ),
    );
  }

  void _onParticipantReconnected(dynamic data) {
    if (data is! Map || state.roomState == null) return;
    final count = data['participantCount'] as int?;
    if (count == null) return;

    var participants = state.roomState!.participants;
    final participantJson = data['participant'];
    if (participantJson is Map) {
      final participant = Participant.fromJson(
        Map<String, dynamic>.from(participantJson),
      );
      if (!participants.any((p) => p.id == participant.id)) {
        participants = [...participants, participant];
      }
    }

    state = state.copyWith(
      roomState: state.roomState!.copyWith(
        participants: participants,
        participantCount: count,
      ),
    );
  }

  void _onHostChanged(dynamic data) {
    if (data is! Map || state.roomState == null) return;
    final newHostId = data['hostId'] as String?;
    final newHostUsername = data['hostUsername'] as String?;
    if (newHostId == null) return;

    final myId = state.participantId;
    state = state.copyWith(
      roomState: state.roomState!.copyWith(
        hostId: newHostId,
        hostUsername: newHostUsername ?? state.roomState!.hostUsername,
        isHost: myId != null && myId == newHostId,
      ),
    );
  }

  void _onPlaybackUpdate(dynamic data) {
    if (data is! Map || state.roomState == null) return;
    final playback = PlaybackState.fromJson(
      Map<String, dynamic>.from(data['playbackState'] as Map),
    );
    state = state.copyWith(
      roomState: state.roomState!.copyWith(playbackState: playback),
    );
  }

  void _onChatMessage(dynamic data) {
    if (data is! Map) return;
    final message = ChatMessage.fromJson(Map<String, dynamic>.from(data));
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void _onVideoReady(dynamic data) {
    if (data is! Map || state.roomState == null) return;
    final relativeUrl = data['videoUrl'] as String?;
    if (relativeUrl == null) return;

    final resolved = _api.resolveVideoUrl(relativeUrl);
    final version = data['videoVersion'] as int? ?? 0;
    final playbackJson = data['playbackState'];

    if (state.roomState!.videoVersion == version && version > 0) {
      return;
    }

    final playback = playbackJson is Map
        ? PlaybackState.fromJson(Map<String, dynamic>.from(playbackJson))
        : PlaybackState.initial();

    state = state.copyWith(
      roomState: state.roomState!.copyWith(
        hasVideo: data['hasVideo'] as bool? ?? true,
        videoUrl: resolved,
        videoVersion: version,
        playbackState: playback,
      ),
    );
  }

  void _onSocketError(dynamic data) {
    if (data is! Map) return;
    state = state.copyWith(error: data['message'] as String? ?? 'Socket error');
  }

  @override
  void dispose() {
    leaveRoom();
    super.dispose();
  }
}

final roomSessionProvider =
    StateNotifierProvider<RoomSessionNotifier, RoomSessionState>((ref) {
  return RoomSessionNotifier(
    ref.watch(apiServiceProvider),
    ref.watch(socketServiceProvider),
  );
});

/// Latest playback state for player sync — updated on every playback_update.
final playbackStateProvider = Provider<PlaybackState?>((ref) {
  return ref.watch(roomSessionProvider).roomState?.playbackState;
});

final isHostProvider = Provider<bool>((ref) {
  return ref.watch(roomSessionProvider).roomState?.isHost ?? false;
});
