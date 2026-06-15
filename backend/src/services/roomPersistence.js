const fs = require('fs');
const path = require('path');
const { VIDEO_STORAGE_DIR } = require('../config');

const ROOMS_FILE = path.join(VIDEO_STORAGE_DIR, '../rooms.json');

function loadRoomsFromDisk() {
  try {
    if (!fs.existsSync(ROOMS_FILE)) return new Map();

    const raw = JSON.parse(fs.readFileSync(ROOMS_FILE, 'utf8'));
    const rooms = new Map();

    for (const [id, data] of Object.entries(raw)) {
      rooms.set(id, {
        ...data,
        participants: new Map(data.participants),
      });
    }

    console.log(`Loaded ${rooms.size} room(s) from disk`);
    return rooms;
  } catch (err) {
    console.error('Failed to load rooms from disk:', err.message);
    return new Map();
  }
}

function saveRoomsToDisk(rooms) {
  try {
    const dir = path.dirname(ROOMS_FILE);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

    const serializable = {};
    for (const [id, room] of rooms) {
      serializable[id] = {
        ...room,
        participants: Array.from(room.participants.entries()),
      };
    }

    fs.writeFileSync(ROOMS_FILE, JSON.stringify(serializable));
  } catch (err) {
    console.error('Failed to save rooms to disk:', err.message);
  }
}

module.exports = { loadRoomsFromDisk, saveRoomsToDisk };
