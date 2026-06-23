const express = require('express');
const cors = require('cors');
const multer = require('multer');
const roomRoutes = require('./routes/roomRoutes');
const videoRoutes = require('./routes/videoRoutes');

function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json());

  app.get('/', (_req, res) => {
    res.json({
      name: 'Rave API',
      status: 'ok',
      message: 'Backend is running. Use the Rave mobile app to create or join a room.',
      health: '/health',
      docs: {
        createRoom: 'POST /api/rooms',
        getRoom: 'GET /api/rooms/:id',
        uploadVideo: 'POST /api/rooms/:id/video',
        streamVideo: 'GET /api/videos/:roomId',
      },
    });
  });

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: Date.now() });
  });

  app.use('/api/rooms', roomRoutes);
  app.use('/api', videoRoutes);

  app.use((err, _req, res, _next) => {
    if (err instanceof multer.MulterError) {
      return res.status(400).json({ error: 'UPLOAD_ERROR', message: err.message });
    }
    if (err.message === 'Unsupported video format') {
      return res.status(400).json({ error: 'INVALID_FORMAT', message: err.message });
    }
    console.error(err);
    res.status(500).json({ error: 'INTERNAL_ERROR', message: 'Something went wrong' });
  });

  return app;
}

module.exports = { createApp };
