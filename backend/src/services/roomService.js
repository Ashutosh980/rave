const { generateRoomId, generateId } = require('../utils/idGenerator');
const { createDefaultPlaybackState } = require('../models/room');
const { MAX_CHAT_MESSAGES } = require('../config');
const { loadRoomsFromDisk, saveRoomsToDisk } = require('./roomPersistence');

/** @type {Map<string, import('../models/room').Room>} */
const rooms = loadRoomsFromDisk();

function normalizeRoomId(roomId) {
  return roomId?.trim().toUpperCase();
}

function persist() {
  saveRoomsToDisk(rooms);
}

function countConnected(room) {
  return Array.from(room.participants.values()).filter((p) => p.socketId).length;
}

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
    videoVersion: 0,
    participants: new Map([[hostId, hostParticipant]]),
    playbackState: createDefaultPlaybackState(),
    chatMessages: [],
    createdAt: Date.now(),
  };

  rooms.set(roomId, room);
  persist();
  return { room, hostId };
}

/** @param {string} roomId */
function getRoom(roomId) {
  const id = normalizeRoomId(roomId);
  return rooms.get(id) || null;
}

/**
 * @param {string} roomId
 * @param {string} username
 * @param {string} [existingParticipantId]
 * @returns {{ room, participant, isReconnect } | { error, message }}
 */
function joinRoom(roomId, username, existingParticipantId) {
  const id = normalizeRoomId(roomId);
  const room = rooms.get(id);
  if (!room) {
    return { error: 'ROOM_NOT_FOUND', message: 'Room not found' };
  }

  if (existingParticipantId && room.participants.has(existingParticipantId)) {
    const participant = room.participants.get(existingParticipantId);
    participant.username = username.trim();
    participant.joinedAt = Date.now();
    persist();
    return { room, participant, isReconnect: true };
  }

  const participant = {
    id: generateId(),
    username: username.trim(),
    socketId: null,
    joinedAt: Date.now(),
  };

  room.participants.set(participant.id, participant);
  persist();
  return { room, participant, isReconnect: false };
}

/**
 * @param {string} roomId
 * @param {string} participantId
 */
function leaveRoom(roomId, participantId) {
  const id = normalizeRoomId(roomId);
  const room = rooms.get(id);
  if (!room) return null;

  const participant = room.participants.get(participantId);
  if (!participant) return null;

  room.participants.delete(participantId);

  if (room.participants.size === 0) {
    rooms.delete(id);
    persist();
    return { room: null, participant, roomDeleted: true };
  }

  if (participantId === room.hostId) {
    const nextHost = room.participants.values().next().value;
    room.hostId = nextHost.id;
    room.hostUsername = nextHost.username;
  }

  persist();
  return { room, participant, roomDeleted: false };
}

/** Mark participant offline on socket disconnect — room is kept alive. */
function markParticipantOffline(roomId, participantId) {
  const id = normalizeRoomId(roomId);
  const room = rooms.get(id);
  if (!room) return null;

  const participant = room.participants.get(participantId);
  if (!participant) return null;

  participant.socketId = null;
  persist();
  return { room, participant };
}

/** @param {string} roomId @param {string} participantId @param {string} socketId */
function bindSocket(roomId, participantId, socketId) {
  const id = normalizeRoomId(roomId);
  const room = rooms.get(id);
  if (!room) return null;
  const participant = room.participants.get(participantId);
  if (!participant) return null;
  participant.socketId = socketId;
  persist();
  return participant;
}

/** @param {string} roomId @param {string} filename */
function setRoomVideo(roomId, filename) {
  const id = normalizeRoomId(roomId);
  const room = rooms.get(id);
  if (!room) return null;
  room.videoFilename = filename;
  room.videoVersion = Date.now();
  room.playbackState = createDefaultPlaybackState();
  persist();
  return room;
}

/**
 * @param {string} roomId
 * @param {string} username
 * @param {string} content
 */
function addChatMessage(roomId, username, content) {
  const id = normalizeRoomId(roomId);
  const room = rooms.get(id);
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

  persist();
  return message;
}

/** Serializes room for API / socket responses (no internal maps). */
function serializeRoom(room, participantId) {
  const connected = Array.from(room.participants.values()).filter((p) => p.socketId);
  return {
    roomId: room.id,
    hostId: room.hostId,
    hostUsername: room.hostUsername,
    hasVideo: Boolean(room.videoFilename),
    videoUrl: room.videoFilename ? `/api/videos/${room.id}` : null,
    videoVersion: room.videoVersion ?? 0,
    participantCount: connected.length,
    isHost: participantId === room.hostId,
    participants: connected.map((p) => ({
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
    participantCount: countConnected(room),
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
  markParticipantOffline,
  bindSocket,
  setRoomVideo,
  addChatMessage,
  serializeRoom,
  serializeRoomPublic,
  countConnected,
  normalizeRoomId,
};
