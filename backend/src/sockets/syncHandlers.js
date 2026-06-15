const { getRoom } = require('../services/roomService');
const { applySyncEvent } = require('../services/syncService');
const { getSocketContext } = require('./roomHandlers');

function isHost(roomId, participantId) {
  const room = getRoom(roomId);
  return room && room.hostId === participantId;
}

function registerSyncHandlers(io, socket) {
  const syncEvents = [
    { event: 'sync_play', type: 'play' },
    { event: 'sync_pause', type: 'pause' },
    { event: 'sync_seek', type: 'seek' },
    { event: 'sync_rate', type: 'rate' },
  ];

  for (const { event, type } of syncEvents) {
    socket.on(event, (payload) => {
      const ctx = getSocketContext(socket);
      if (!ctx) {
        socket.emit('error', { code: 'NOT_IN_ROOM', message: 'Join a room first' });
        return;
      }

      if (!isHost(ctx.roomId, ctx.participantId)) {
        socket.emit('error', { code: 'NOT_HOST', message: 'Only the host can control playback' });
        return;
      }

      const result = applySyncEvent(ctx.roomId, type, payload || {});
      if (!result) {
        socket.emit('error', { code: 'SYNC_FAILED', message: 'Failed to apply sync event' });
        return;
      }

      io.to(ctx.roomId).emit('playback_update', {
        playbackState: result.playbackState,
        authoritativeTime: result.authoritativeTime,
        eventType: result.eventType,
        hostId: ctx.participantId,
      });
    });
  }
}

module.exports = { registerSyncHandlers };
