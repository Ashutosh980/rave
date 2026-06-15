const express = require('express');
const { createRoomHandler, getRoomHandler } = require('../controllers/roomController');

const router = express.Router();

router.post('/', createRoomHandler);
router.get('/:id', getRoomHandler);

module.exports = router;
