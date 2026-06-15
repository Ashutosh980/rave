const fs = require('fs');
const path = require('path');
const { VIDEO_STORAGE_DIR } = require('../config');
const { getRoom, setRoomVideo } = require('./roomService');

function ensureStorageDir() {
  if (!fs.existsSync(VIDEO_STORAGE_DIR)) {
    fs.mkdirSync(VIDEO_STORAGE_DIR, { recursive: true });
  }
}

/**
 * Saves uploaded file for a room. Filename: {roomId}{originalExt}
 * @param {string} roomId
 * @param {Express.Multer.File} file
 */
function saveVideo(roomId, file) {
  const ext = path.extname(file.originalname) || '.mp4';
  const filename = `${roomId}${ext}`;
  const destPath = path.join(VIDEO_STORAGE_DIR, filename);

  fs.renameSync(file.path, destPath);
  setRoomVideo(roomId, filename);

  const stats = fs.statSync(destPath);
  return { filename, size: stats.size, path: destPath };
}

/** @param {string} roomId */
function getVideoPath(roomId) {
  const room = getRoom(roomId);
  if (!room || !room.videoFilename) return null;

  const filePath = path.join(VIDEO_STORAGE_DIR, room.videoFilename);
  if (!fs.existsSync(filePath)) return null;

  return filePath;
}

/** @param {string} roomId */
function getVideoStats(roomId) {
  const filePath = getVideoPath(roomId);
  if (!filePath) return null;
  return fs.statSync(filePath);
}

module.exports = {
  ensureStorageDir,
  saveVideo,
  getVideoPath,
  getVideoStats,
};
