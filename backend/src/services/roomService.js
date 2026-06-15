const { generateRoomId, generateId } = require('../utils/idGenerator');
const { createDefaultPlaybackState } = require('../models/room');
const { MAX_CHAT_MESSAGES } = require('../config');

/** @type {Map<string, import('../models/room').Room>} */
const rooms = new Map();

/**
 * Creates a new room with the given host username.
 * @param {string} hostUsername
 * @returns {{ room: import('../models/room').Room, hostId: string }}
 */
function createRoom(hostUsername) {
  const roomId = generateRoomId();
  const hostId = generateId();

  const hostParticipant = {
    id: hostId,
    username: hostUsername.trim(),
    socketId: null,
    joinedAt: Date.now(),
  };

  const room = {
    id: roomId,
    hostId,
    hostUsername: hostParticipant.username,
    videoFilename: null,
    participants: new Map([[hostId, hostParticipant]]),
    playbackState: createDefaultPlaybackState(),
    chatMessages: [],
    createdAt: Date.now(),
  };

  rooms.set(roomId, room);
  return { room, hostId };
}

/** @param {string} roomId */
function getRoom(roomId) {
  return rooms.get(roomId) || null;
}

/**
 * @param {string} roomId
 * @param {string} username
 * @param {string} [existingParticipantId]
 * @returns {{ room, participant, isReconnect } | { error, message }}
 */
function joinRoom(roomId, username, existingParticipantId) {
  const room = rooms.get(roomId);
  if (!room) {
    return { error: 'ROOM_NOT_FOUND', message: 'Room not found' };
  }

  if (existingParticipantId && room.participants.has(existingParticipantId)) {
    const participant = room.participants.get(existingParticipantId);
    participant.username = username.trim();
    participant.joinedAt = Date.now();
    return { room, participant, isReconnect: true };
  }

  const participant = {
    id: generateId(),
    username: username.trim(),
    socketId: null,
    joinedAt: Date.now(),
  };

  room.participants.set(participant.id, participant);
  return { room, participant, isReconnect: false };
}

/**
 * @param {string} roomId
 * @param {string} participantId
 */
function leaveRoom(roomId, participantId) {
  const room = rooms.get(roomId);
  if (!room) return null;

  const participant = room.participants.get(participantId);
  if (!participant) return null;

  room.participants.delete(participantId);

  if (room.participants.size === 0) {
    rooms.delete(roomId);
    return { room: null, participant, roomDeleted: true };
  }

  if (participantId === room.hostId) {
    const nextHost = room.participants.values().next().value;
    room.hostId = nextHost.id;
    room.hostUsername = nextHost.username;
  }

  return { room, participant, roomDeleted: false };
}

/** @param {string} roomId @param {string} participantId @param {string} socketId */
function bindSocket(roomId, participantId, socketId) {
  const room = rooms.get(roomId);
  if (!room) return null;
  const participant = room.participants.get(participantId);
  if (!participant) return null;
  participant.socketId = socketId;
  return participant;
}

/** @param {string} roomId @param {string} filename */
function setRoomVideo(roomId, filename) {
  const room = rooms.get(roomId);
  if (!room) return null;
  room.videoFilename = filename;
  return room;
}

/**
 * @param {string} roomId
 * @param {string} username
 * @param {string} content
 */
function addChatMessage(roomId, username, content) {
  const room = rooms.get(roomId);
  if (!room) return null;

  const message = {
    id: generateId(),
    username,
    content: content.trim(),
    timestamp: Date.now(),
  };

  room.chatMessages.push(message);
  if (room.chatMessages.length > MAX_CHAT_MESSAGES) {
    room.chatMessages = room.chatMessages.slice(-MAX_CHAT_MESSAGES);
  }

  return message;
}

/** Serializes room for API / socket responses (no internal maps). */
function serializeRoom(room, participantId) {
  return {
    roomId: room.id,
    hostId: room.hostId,
    hostUsername: room.hostUsername,
    hasVideo: Boolean(room.videoFilename),
    videoUrl: room.videoFilename ? `/api/videos/${room.id}` : null,
    participantCount: room.participants.size,
    isHost: participantId === room.hostId,
    participants: Array.from(room.participants.values()).map((p) => ({
      id: p.id,
      username: p.username,
      joinedAt: p.joinedAt,
    })),
    playbackState: { ...room.playbackState },
    chatMessages: [...room.chatMessages],
    createdAt: room.createdAt,
  };
}

/** Public room summary for GET without joining. */
function serializeRoomPublic(room) {
  return {
    roomId: room.id,
    hostUsername: room.hostUsername,
    hasVideo: Boolean(room.videoFilename),
    participantCount: room.participants.size,
    playbackState: { ...room.playbackState },
    createdAt: room.createdAt,
  };
}

module.exports = {
  rooms,
  createRoom,
  getRoom,
  joinRoom,
  leaveRoom,
  bindSocket,
  setRoomVideo,
  addChatMessage,
  serializeRoom,
  serializeRoomPublic,
};
