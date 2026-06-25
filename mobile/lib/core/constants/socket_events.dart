class SocketEvents {
  static const joinRoom = 'join_room';
  static const leaveRoom = 'leave_room';
  static const roomState = 'room_state';
  static const participantJoined = 'participant_joined';
  static const participantLeft = 'participant_left';
  static const participantOffline = 'participant_offline';
  static const participantReconnected = 'participant_reconnected';
  static const hostChanged = 'host_changed';

  static const syncPlay = 'sync_play';
  static const syncPause = 'sync_pause';
  static const syncSeek = 'sync_seek';
  static const syncRate = 'sync_rate';
  static const playbackUpdate = 'playback_update';

  static const chatMessage = 'chat_message';
  static const videoReady = 'video_ready';
  static const error = 'error';

  // Phase 2 live stream / WebRTC signaling
  static const liveStreamStart = 'live_stream_start';
  static const liveStreamStop = 'live_stream_stop';
  static const liveStreamAvailable = 'live_stream_available';
  static const liveStreamEnded = 'live_stream_ended';
  static const webrtcOffer = 'webrtc_offer';
  static const webrtcAnswer = 'webrtc_answer';
  static const webrtcIceCandidate = 'webrtc_ice_candidate';
}
