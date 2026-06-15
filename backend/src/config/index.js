const path = require('path');

const PORT = parseInt(process.env.PORT || '3000', 10);
const HOST = process.env.HOST || '0.0.0.0';
const VIDEO_STORAGE_DIR = process.env.VIDEO_STORAGE_DIR
  || path.join(__dirname, '../../storage/videos');
const MAX_VIDEO_SIZE_MB = parseInt(process.env.MAX_VIDEO_SIZE_MB || '2048', 10);
const MAX_CHAT_MESSAGES = 100;
const DRIFT_THRESHOLD_MS = 500;

module.exports = {
  PORT,
  HOST,
  VIDEO_STORAGE_DIR,
  MAX_VIDEO_SIZE_MB,
  MAX_CHAT_MESSAGES,
  DRIFT_THRESHOLD_MS,
};
