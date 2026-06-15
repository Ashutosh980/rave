class SocketEvents {
  static const joinRoom = 'join_room';
  static const leaveRoom = 'leave_room';
  static const roomState = 'room_state';
  static const participantJoined = 'participant_joined';
  static const participantLeft = 'participant_left';
  static const participantOffline = 'participant_offline';
  static const participantReconnected = 'participant_reconnected';

  static const syncPlay = 'sync_play';
  static const syncPause = 'sync_pause';
  static const syncSeek = 'sync_seek';
  static const syncRate = 'sync_rate';
  static const playbackUpdate = 'playback_update';

  static const chatMessage = 'chat_message';
  static const videoReady = 'video_ready';
  static const error = 'error';
}
