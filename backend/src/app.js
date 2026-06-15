const express = require('express');
const cors = require('cors');
const multer = require('multer');
const roomRoutes = require('./routes/roomRoutes');
const videoRoutes = require('./routes/videoRoutes');

function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json());

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
