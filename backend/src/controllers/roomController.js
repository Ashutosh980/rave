const { createRoom, getRoom, serializeRoomPublic } = require('../services/roomService');

function createRoomHandler(req, res) {
  const { username } = req.body;

  if (!username || typeof username !== 'string' || !username.trim()) {
    return res.status(400).json({ error: 'VALIDATION_ERROR', message: 'username is required' });
  }

  const { room, hostId } = createRoom(username);
  return res.status(201).json({
    roomId: room.id,
    hostId,
    hostUsername: room.hostUsername,
    createdAt: room.createdAt,
  });
}

function getRoomHandler(req, res) {
  const room = getRoom(req.params.id);
  if (!room) {
    return res.status(404).json({ error: 'ROOM_NOT_FOUND', message: 'Room not found' });
  }
  return res.json(serializeRoomPublic(room));
}

module.exports = { createRoomHandler, getRoomHandler };
