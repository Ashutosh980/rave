const {
  joinRoom,
  leaveRoom,
  markParticipantOffline,
  bindSocket,
  addChatMessage,
  serializeRoom,
  getRoom,
  countConnected,
  normalizeRoomId,
} = require('../services/roomService');

/** socketId -> { roomId, participantId, username } */
const socketRegistry = new Map();

function getSocketContext(socket) {
  return socketRegistry.get(socket.id) || null;
}

function registerSocketHandlers(io, socket) {
  socket.on('join_room', (payload, ack) => {
    const { roomId: rawRoomId, username, participantId } = payload || {};
    const roomId = normalizeRoomId(rawRoomId);

    if (!roomId || !username) {
      const err = { code: 'VALIDATION_ERROR', message: 'roomId and username are required' };
      socket.emit('error', err);
      if (typeof ack === 'function') ack({ ok: false, ...err });
      return;
    }

    const result = joinRoom(roomId, username, participantId);
    if (result.error) {
      socket.emit('error', { code: result.error, message: result.message });
      if (typeof ack === 'function') ack({ ok: false, code: result.error, message: result.message });
      return;
    }

    const { room, participant, isReconnect } = result;
    bindSocket(roomId, participant.id, socket.id);

    socketRegistry.set(socket.id, {
      roomId,
      participantId: participant.id,
      username: participant.username,
    });

    socket.join(roomId);

    const roomState = serializeRoom(room, participant.id);
    socket.emit('room_state', roomState);

    if (!isReconnect) {
      socket.to(roomId).emit('participant_joined', {
        participant: {
          id: participant.id,
          username: participant.username,
          joinedAt: participant.joinedAt,
        },
        participantCount: countConnected(room),
      });
    } else {
      socket.to(roomId).emit('participant_reconnected', {
        participant: {
          id: participant.id,
          username: participant.username,
          joinedAt: participant.joinedAt,
        },
        participantId: participant.id,
        participantCount: countConnected(room),
      });
    }

    if (typeof ack === 'function') {
      ack({ ok: true, participantId: participant.id, roomState });
    }
  });

  socket.on('leave_room', (payload) => {
    const ctx = getSocketContext(socket);
    const roomId = normalizeRoomId(payload?.roomId || ctx?.roomId);
    const participantId = ctx?.participantId;

    if (!roomId || !participantId) return;

    const result = leaveRoom(roomId, participantId);
    socket.leave(roomId);
    socketRegistry.delete(socket.id);

    if (result?.participant) {
      socket.to(roomId).emit('participant_left', {
        participantId,
        participantCount: result.room?.participants.size ?? 0,
      });
    }
  });

  socket.on('chat_message', (payload) => {
    const ctx = getSocketContext(socket);
    if (!ctx) {
      socket.emit('error', { code: 'NOT_IN_ROOM', message: 'Join a room first' });
      return;
    }

    const content = payload?.content;
    if (!content || typeof content !== 'string' || !content.trim()) {
      socket.emit('error', { code: 'VALIDATION_ERROR', message: 'Message content is required' });
      return;
    }

    const message = addChatMessage(ctx.roomId, ctx.username, content);
    if (!message) {
      socket.emit('error', { code: 'ROOM_NOT_FOUND', message: 'Room not found' });
      return;
    }

    io.to(ctx.roomId).emit('chat_message', message);
  });

  socket.on('video_ready', () => {
    const ctx = getSocketContext(socket);
    if (!ctx) return;

    const room = getRoom(ctx.roomId);
    if (!room || room.hostId !== ctx.participantId || !room.videoFilename) return;

    io.to(ctx.roomId).emit('video_ready', {
      videoUrl: `/api/videos/${room.id}`,
      hasVideo: true,
    });
  });

  socket.on('disconnect', () => {
    const ctx = socketRegistry.get(socket.id);
    if (!ctx) return;

    const result = markParticipantOffline(ctx.roomId, ctx.participantId);
    socketRegistry.delete(socket.id);

    if (result?.room) {
      socket.to(ctx.roomId).emit('participant_offline', {
        participantId: ctx.participantId,
        participantCount: countConnected(result.room),
      });
    }
  });
}

module.exports = { registerSocketHandlers, getSocketContext, socketRegistry };
