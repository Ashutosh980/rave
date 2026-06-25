const { getSocketContext } = require('./roomHandlers');
const { getRoom, setLiveStream } = require('../services/roomService');

/**
 * Phase 2 WebRTC signaling stubs.
 * See docs/LIVE_STREAM.md for full design.
 */
function registerWebRtcHandlers(io, socket) {
  socket.on('live_stream_start', (payload) => {
    const ctx = getSocketContext(socket);
    if (!ctx) return;

    const room = getRoom(ctx.roomId);
    if (!room || room.hostId !== ctx.participantId) {
      socket.emit('error', { code: 'NOT_HOST', message: 'Only the host can start a live stream' });
      return;
    }

    const source = payload?.source === 'screen' ? 'screen' : 'camera';
    setLiveStream(ctx.roomId, true, source);
    io.to(ctx.roomId).emit('live_stream_available', {
      hostId: ctx.participantId,
      source,
    });
  });

  socket.on('live_stream_stop', () => {
    const ctx = getSocketContext(socket);
    if (!ctx) return;

    const room = getRoom(ctx.roomId);
    if (!room || room.hostId !== ctx.participantId) return;

    setLiveStream(ctx.roomId, false);
    io.to(ctx.roomId).emit('live_stream_ended', { hostId: ctx.participantId });
  });

  const relayEvents = ['webrtc_offer', 'webrtc_answer', 'webrtc_ice_candidate'];

  for (const event of relayEvents) {
    socket.on(event, (payload) => {
      const ctx = getSocketContext(socket);
      if (!ctx) return;

      const toParticipantId = payload?.toParticipantId;
      if (!toParticipantId) {
        socket.emit('error', { code: 'VALIDATION_ERROR', message: 'toParticipantId is required' });
        return;
      }

      const room = getRoom(ctx.roomId);
      if (!room || !room.participants.has(toParticipantId)) {
        socket.emit('error', { code: 'PARTICIPANT_NOT_FOUND', message: 'Recipient not in room' });
        return;
      }

      const recipient = room.participants.get(toParticipantId);
      if (!recipient?.socketId) return;

      io.to(recipient.socketId).emit(event, {
        fromParticipantId: ctx.participantId,
        sdp: payload.sdp,
        candidate: payload.candidate,
      });
    });
  }
}

module.exports = { registerWebRtcHandlers };
