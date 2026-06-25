import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/constants/socket_events.dart';

typedef SocketCallback = void Function(dynamic data);

class SocketService {
  SocketService({required this.serverUrl});

  final String serverUrl;
  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (_socket?.connected == true) return;

    _socket?.dispose();

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .build(),
    );

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void on(String event, SocketCallback handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void emit(String event, dynamic data, [void Function(dynamic)? ack]) {
    if (ack != null) {
      _socket?.emitWithAck(event, data, ack: ack);
    } else {
      _socket?.emit(event, data);
    }
  }

  Future<Map<String, dynamic>> joinRoom({
    required String roomId,
    required String username,
    String? participantId,
  }) async {
    return _emitWithAck(SocketEvents.joinRoom, {
      'roomId': roomId,
      'username': username,
      'participantId': ?participantId,
    });
  }

  void leaveRoom(String roomId) {
    emit(SocketEvents.leaveRoom, {'roomId': roomId});
  }

  void sendChatMessage(String content) {
    emit(SocketEvents.chatMessage, {'content': content});
  }

  void notifyVideoReady() {
    emit(SocketEvents.videoReady, {});
  }

  void syncPlay({required double time, double? rate}) {
    emit(SocketEvents.syncPlay, {
      'time': time,
      'rate': ?rate,
    });
  }

  void syncPause({required double time}) {
    emit(SocketEvents.syncPause, {'time': time});
  }

  void syncSeek({required double time}) {
    emit(SocketEvents.syncSeek, {'time': time});
  }

  void syncRate({required double rate, required double time}) {
    emit(SocketEvents.syncRate, {'rate': rate, 'time': time});
  }

  Future<Map<String, dynamic>> _emitWithAck(
    String event,
    Map<String, dynamic> data,
  ) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('Socket not connected');
    }

    final completer = Completer<Map<String, dynamic>>();

    socket.emitWithAck(event, data, ack: (response) {
      if (response is Map) {
        final map = Map<String, dynamic>.from(response);
        if (map['ok'] == false) {
          completer.completeError(
            SocketException(map['message'] as String? ?? 'Socket error'),
          );
        } else {
          completer.complete(map);
        }
      } else {
        completer.completeError(SocketException('Invalid ack response'));
      }
    });

    return completer.future;
  }
}

class SocketException implements Exception {
  SocketException(this.message);
  final String message;

  @override
  String toString() => message;
}
