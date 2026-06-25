import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/socket_events.dart';
import '../../../core/providers/app_providers.dart';
import '../../../services/socket_service.dart';
import '../../room/providers/room_provider.dart';

enum LiveStreamSource { camera, screen }

enum LiveStreamRole { none, host, viewer }

class LiveStreamState {
  const LiveStreamState({
    this.isActive = false,
    this.isConnecting = false,
    this.source,
    this.role = LiveStreamRole.none,
    this.localStream,
    this.remoteStream,
    this.hostId,
    this.error,
  });

  final bool isActive;
  final bool isConnecting;
  final LiveStreamSource? source;
  final LiveStreamRole role;
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final String? hostId;
  final String? error;

  bool get showLiveVideo => localStream != null || remoteStream != null;

  LiveStreamState copyWith({
    bool? isActive,
    bool? isConnecting,
    LiveStreamSource? source,
    LiveStreamRole? role,
    MediaStream? localStream,
    MediaStream? remoteStream,
    String? hostId,
    String? error,
    bool clearLocalStream = false,
    bool clearRemoteStream = false,
    bool clearError = false,
  }) {
    return LiveStreamState(
      isActive: isActive ?? this.isActive,
      isConnecting: isConnecting ?? this.isConnecting,
      source: source ?? this.source,
      role: role ?? this.role,
      localStream: clearLocalStream ? null : (localStream ?? this.localStream),
      remoteStream: clearRemoteStream ? null : (remoteStream ?? this.remoteStream),
      hostId: hostId ?? this.hostId,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LiveStreamNotifier extends StateNotifier<LiveStreamState> {
  LiveStreamNotifier(this._ref) : super(const LiveStreamState()) {
    _registerSocketListeners();
    _ref.listen(roomSessionProvider, _onRoomSessionChanged);
    _ref.listen(
      roomSessionProvider.select((s) => s.roomState?.hostId),
      (prev, next) {
        if (prev != null && next != null && prev != next && state.role == LiveStreamRole.viewer) {
          unawaited(stopStream());
        }
      },
    );
  }

  final Ref _ref;
  final Map<String, RTCPeerConnection> _hostPeerConnections = {};
  RTCPeerConnection? _viewerPeerConnection;
  String? _viewerHostId;
  bool _listenersRegistered = false;
  bool _viewerConnecting = false;

  static const _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  SocketService get _socket => _ref.read(socketServiceProvider);

  void _registerSocketListeners() {
    if (_listenersRegistered) return;
    _listenersRegistered = true;

    _socket.on(SocketEvents.liveStreamAvailable, _onLiveStreamAvailable);
    _socket.on(SocketEvents.liveStreamEnded, _onLiveStreamEnded);
    _socket.on(SocketEvents.webrtcOffer, _onWebRtcOffer);
    _socket.on(SocketEvents.webrtcAnswer, _onWebRtcAnswer);
    _socket.on(SocketEvents.webrtcIceCandidate, _onWebRtcIceCandidate);
  }

  void _onRoomSessionChanged(RoomSessionState? prev, RoomSessionState next) {
    final room = next.roomState;
    if (room == null) return;

    if (room.isHost || !room.liveStream.active) return;
    if (state.isActive && state.role == LiveStreamRole.viewer) return;

    unawaited(_connectAsViewer(room.hostId));
  }

  Future<void> startStream(LiveStreamSource source) async {
    final room = _ref.read(roomSessionProvider).roomState;
    if (room == null || !room.isHost) {
      state = state.copyWith(error: 'Only the host can start a live stream');
      return;
    }

    if (state.isActive || state.isConnecting) return;

    state = state.copyWith(isConnecting: true, clearError: true);

    try {
      if (source == LiveStreamSource.camera) {
        final granted = await _ensureCameraPermission();
        if (!granted) {
          throw Exception('Camera permission denied');
        }
      }

      final stream = await _captureStream(source);
      state = state.copyWith(
        isActive: true,
        isConnecting: false,
        role: LiveStreamRole.host,
        source: source,
        localStream: stream,
        hostId: _ref.read(roomSessionProvider).participantId,
        clearError: true,
      );

      _socket.liveStreamStart(
        source: source == LiveStreamSource.screen ? 'screen' : 'camera',
      );
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        isActive: false,
        error: e.toString(),
      );
    }
  }

  Future<void> stopStream() async {
    if (state.role == LiveStreamRole.host && state.isActive) {
      _socket.liveStreamStop();
    }
    await _cleanup();
    state = const LiveStreamState();
  }

  Future<MediaStream> _captureStream(LiveStreamSource source) async {
    if (source == LiveStreamSource.screen) {
      return navigator.mediaDevices.getDisplayMedia({
        'video': {'deviceId': 'broadcast'},
        'audio': false,
      });
    }

    return navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': {
        'facingMode': 'user',
        'width': 1280,
        'height': 720,
      },
    });
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  void _onLiveStreamAvailable(dynamic data) {
    if (data is! Map) return;
    final hostId = data['hostId'] as String?;
    if (hostId == null) return;

    final myId = _ref.read(roomSessionProvider).participantId;
    if (myId == hostId) return;

    unawaited(_connectAsViewer(hostId));
  }

  void _onLiveStreamEnded(dynamic data) {
    if (state.role != LiveStreamRole.viewer) return;
    unawaited(_cleanupViewer());
    state = const LiveStreamState();
  }

  Future<void> _connectAsViewer(String hostId) async {
    if (_viewerConnecting) return;
    if (state.role == LiveStreamRole.host) return;

    _viewerConnecting = true;
    state = state.copyWith(
      isConnecting: true,
      role: LiveStreamRole.viewer,
      hostId: hostId,
      clearError: true,
    );

    try {
      await _cleanupViewer();

      final pc = await createPeerConnection(_rtcConfig);
      _viewerPeerConnection = pc;
      _viewerHostId = hostId;

      pc.onTrack = (event) {
        if (event.streams.isEmpty) return;
        state = state.copyWith(
          isActive: true,
          isConnecting: false,
          remoteStream: event.streams.first,
        );
      };

      pc.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        _socket.sendWebRtcIceCandidate(
          toParticipantId: hostId,
          candidate: candidate.toMap(),
        );
      };

      final offer = await pc.createOffer({
        'offerToReceiveVideo': true,
        'offerToReceiveAudio': false,
      });
      await pc.setLocalDescription(offer);

      _socket.sendWebRtcOffer(
        toParticipantId: hostId,
        sdp: offer.toMap(),
      );
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        isActive: false,
        error: e.toString(),
      );
    } finally {
      _viewerConnecting = false;
    }
  }

  Future<void> _onWebRtcOffer(dynamic data) async {
    if (data is! Map) return;
    if (state.role != LiveStreamRole.host || state.localStream == null) return;

    final viewerId = data['fromParticipantId'] as String?;
    final sdpMap = data['sdp'];
    if (viewerId == null || sdpMap is! Map) return;

    try {
      var pc = _hostPeerConnections[viewerId];
      if (pc == null) {
        pc = await _createHostPeerConnection(viewerId);
        _hostPeerConnections[viewerId] = pc;
      }

      final offer = _parseSdp(sdpMap);
      await pc.setRemoteDescription(offer);

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      _socket.sendWebRtcAnswer(
        toParticipantId: viewerId,
        sdp: answer.toMap(),
      );
    } catch (e) {
      debugPrint('WebRTC offer handling failed: $e');
    }
  }

  Future<void> _onWebRtcAnswer(dynamic data) async {
    if (data is! Map) return;
    if (state.role != LiveStreamRole.viewer) return;

    final sdpMap = data['sdp'];
    if (sdpMap is! Map || _viewerPeerConnection == null) return;

    try {
      await _viewerPeerConnection!.setRemoteDescription(_parseSdp(sdpMap));
      state = state.copyWith(isConnecting: false);
    } catch (e) {
      debugPrint('WebRTC answer handling failed: $e');
    }
  }

  Future<void> _onWebRtcIceCandidate(dynamic data) async {
    if (data is! Map) return;

    final fromId = data['fromParticipantId'] as String?;
    final candidateMap = data['candidate'];
    if (fromId == null || candidateMap is! Map) return;

    final candidate = _parseIceCandidate(candidateMap);
    if (candidate.candidate == null || candidate.candidate!.isEmpty) return;

    try {
      if (state.role == LiveStreamRole.host) {
        final pc = _hostPeerConnections[fromId];
        await pc?.addCandidate(candidate);
      } else if (state.role == LiveStreamRole.viewer &&
          fromId == _viewerHostId) {
        await _viewerPeerConnection?.addCandidate(candidate);
      }
    } catch (e) {
      debugPrint('ICE candidate handling failed: $e');
    }
  }

  Future<RTCPeerConnection> _createHostPeerConnection(String viewerId) async {
    final pc = await createPeerConnection(_rtcConfig);
    final stream = state.localStream!;

    for (final track in stream.getTracks()) {
      await pc.addTrack(track, stream);
    }

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _socket.sendWebRtcIceCandidate(
        toParticipantId: viewerId,
        candidate: candidate.toMap(),
      );
    };

    return pc;
  }

  RTCSessionDescription _parseSdp(Map<dynamic, dynamic> sdp) {
    return RTCSessionDescription(
      sdp['sdp'] as String,
      sdp['type'] as String,
    );
  }

  RTCIceCandidate _parseIceCandidate(Map<dynamic, dynamic> candidate) {
    return RTCIceCandidate(
      candidate['candidate'] as String?,
      candidate['sdpMid'] as String?,
      candidate['sdpMLineIndex'] as int?,
    );
  }

  Future<void> _cleanupViewer() async {
    await _viewerPeerConnection?.close();
    _viewerPeerConnection = null;
    _viewerHostId = null;
    state.remoteStream?.getTracks().forEach((t) => t.stop());
  }

  Future<void> _cleanup() async {
    for (final pc in _hostPeerConnections.values) {
      await pc.close();
    }
    _hostPeerConnections.clear();

    await _cleanupViewer();

    state.localStream?.getTracks().forEach((t) => t.stop());
    state.remoteStream?.getTracks().forEach((t) => t.stop());
  }

  void teardownListeners() {
    if (!_listenersRegistered) return;
    _socket.off(SocketEvents.liveStreamAvailable);
    _socket.off(SocketEvents.liveStreamEnded);
    _socket.off(SocketEvents.webrtcOffer);
    _socket.off(SocketEvents.webrtcAnswer);
    _socket.off(SocketEvents.webrtcIceCandidate);
    _listenersRegistered = false;
  }

  @override
  void dispose() {
    teardownListeners();
    unawaited(_cleanup());
    super.dispose();
  }
}

final liveStreamProvider =
    StateNotifierProvider.autoDispose<LiveStreamNotifier, LiveStreamState>(
  (ref) => LiveStreamNotifier(ref),
);
