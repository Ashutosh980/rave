const express = require('express');
const { upload, uploadVideoHandler, streamVideoHandler } = require('../controllers/videoController');

const router = express.Router();

router.post('/rooms/:id/video', upload.single('video'), uploadVideoHandler);
router.get('/videos/:roomId', streamVideoHandler);

module.exports = router;
