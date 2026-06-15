const { v4: uuidv4 } = require('uuid');

/** Generates a short human-friendly room code (8 chars, uppercase). */
function generateRoomId() {
  return uuidv4().replace(/-/g, '').slice(0, 8).toUpperCase();
}

function generateId() {
  return uuidv4();
}

module.exports = { generateRoomId, generateId };
