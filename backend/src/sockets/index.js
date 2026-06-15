const { Server } = require('socket.io');
const { registerSocketHandlers } = require('./roomHandlers');
const { registerSyncHandlers } = require('./syncHandlers');

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

  io.on('connection', (socket) => {
    registerSocketHandlers(io, socket);
    registerSyncHandlers(io, socket);

    // TODO Phase 2: WebRTC signaling events (offer, answer, ice-candidate)
  });

  return io;
}

module.exports = { initSockets };
