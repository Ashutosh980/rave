const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { MAX_VIDEO_SIZE_MB, VIDEO_STORAGE_DIR } = require('../config');
const { getRoom } = require('../services/roomService');
const { saveVideo, getVideoPath, getVideoStats } = require('../services/videoService');
const { parseRangeHeader, streamRange } = require('../utils/rangeRequest');
const { getIo } = require('../sockets/io');

function broadcastVideoReady(roomId) {
  const io = getIo();
  if (!io) return;

  const room = getRoom(roomId);
  if (!room) return;

  io.to(roomId).emit('video_ready', {
    videoUrl: `/api/videos/${roomId}`,
    hasVideo: true,
    videoVersion: room.videoVersion ?? 0,
    playbackState: { ...room.playbackState },
  });
}

const upload = multer({
  dest: VIDEO_STORAGE_DIR,
  limits: { fileSize: MAX_VIDEO_SIZE_MB * 1024 * 1024 },
  fileFilter(_req, file, cb) {
    const allowed = /\.(mp4|webm|mkv|mov|avi)$/i;
    if (allowed.test(path.extname(file.originalname))) {
      cb(null, true);
    } else {
      cb(new Error('Unsupported video format'));
    }
  },
});

function uploadVideoHandler(req, res) {
  const room = getRoom(req.params.id);
  if (!room) {
    if (req.file) fs.unlinkSync(req.file.path);
    return res.status(404).json({ error: 'ROOM_NOT_FOUND', message: 'Room not found' });
  }

  const participantId = req.headers['x-participant-id'];
  if (!participantId || participantId !== room.hostId) {
    if (req.file) fs.unlinkSync(req.file.path);
    return res.status(403).json({
      error: 'NOT_HOST',
      message: 'Only the room host can upload video',
    });
  }

  if (!req.file) {
    return res.status(400).json({ error: 'VALIDATION_ERROR', message: 'video file is required' });
  }

  try {
    const result = saveVideo(room.id, req.file);
    const updatedRoom = getRoom(room.id);
    broadcastVideoReady(room.id);
    return res.status(201).json({
      filename: result.filename,
      size: result.size,
      videoUrl: `/api/videos/${room.id}`,
      videoVersion: updatedRoom?.videoVersion ?? 0,
      playbackState: updatedRoom?.playbackState,
    });
  } catch (err) {
    if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
    return res.status(500).json({ error: 'UPLOAD_FAILED', message: err.message });
  }
}

function streamVideoHandler(req, res) {
  const filePath = getVideoPath(req.params.roomId);
  if (!filePath) {
    return res.status(404).json({ error: 'VIDEO_NOT_FOUND', message: 'Video not found for this room' });
  }

  const stats = getVideoStats(req.params.roomId);
  const fileSize = stats.size;
  const range = parseRangeHeader(req.headers.range, fileSize);

  res.set('Accept-Ranges', 'bytes');

  if (range) {
    return streamRange(res, filePath, range, fileSize);
  }

  res.set({
    'Content-Length': fileSize,
    'Content-Type': 'video/mp4',
  });
  fs.createReadStream(filePath).pipe(res);
}

module.exports = { upload, uploadVideoHandler, streamVideoHandler };
