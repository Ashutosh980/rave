/** @type {import('socket.io').Server | null} */
let io = null;

/** @param {import('socket.io').Server} server */
function setIo(server) {
  io = server;
}

function getIo() {
  return io;
}

module.exports = { setIo, getIo };
