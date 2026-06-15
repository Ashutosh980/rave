const http = require('http');
const { createApp } = require('./app');
const { initSockets } = require('./sockets');
const { ensureStorageDir } = require('./services/videoService');
const { PORT, HOST } = require('./config');

ensureStorageDir();

const app = createApp();
const server = http.createServer(app);
initSockets(server);

server.listen(PORT, HOST, () => {
  console.log(`Rave backend listening on http://${HOST}:${PORT}`);
  console.log(`Health: http://localhost:${PORT}/health`);
});
