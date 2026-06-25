const { Server } = require('socket.io');
const { registerSocketHandlers } = require('./roomHandlers');
const { registerSyncHandlers } = require('./syncHandlers');
const { registerWebRtcHandlers } = require('./webrtcHandlers');
const { setIo } = require('./io');

/**
 * Attaches Socket.IO to the HTTP server.
 * @param {import('http').Server} httpServer
 * @returns {import('socket.io').Server}
 */
function initSockets(httpServer) {
  const io = new Server(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
    pingInterval: 10000,
    pingTimeout: 5000,
  });

  setIo(io);

  io.on('connection', (socket) => {
    registerSocketHandlers(io, socket);
    registerSyncHandlers(io, socket);
    registerWebRtcHandlers(io, socket);
  });

  return io;
}

module.exports = { initSockets };
