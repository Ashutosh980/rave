# Rave — Phase 1 Watch Party Platform

Private watch-party MVP: create/join rooms, upload & stream video with synchronized playback, and real-time chat.

## Project Structure

```
rave/
├── docs/ARCHITECTURE.md      # System design, API contracts, data models
├── backend/                  # Node.js + Express + Socket.IO
│   └── src/
│       ├── routes/           # REST endpoints
│       ├── controllers/      # Request handlers
│       ├── sockets/          # Real-time events (sync, chat, room)
│       ├── services/         # Business logic
│       ├── models/           # Data shape definitions
│       └── utils/            # ID generation, HTTP range parsing
└── mobile/                   # Flutter app (Android-first)
    └── lib/
        ├── core/             # Config, theme, constants
        ├── models/           # Dart data models
        ├── services/         # HTTP + Socket.IO clients
        └── features/
            ├── room/         # Create/join room UI
            ├── player/       # media_kit player + sync
            └── chat/         # Real-time chat panel
```

## Setup — Backend

```bash
cd backend
npm install
npm run dev          # starts on http://localhost:3000
```

Environment variables (optional):

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3000` | Server port |
| `HOST` | `0.0.0.0` | Bind address |
| `MAX_VIDEO_SIZE_MB` | `2048` | Upload limit |

## Setup — Flutter

```bash
cd mobile
flutter pub get
flutter run
```

For a **physical device**, pass your machine's LAN IP:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.x:3000 --dart-define=SOCKET_URL=http://192.168.1.x:3000
```

Android emulator uses `10.0.2.2:3000` by default (host machine localhost).

## Testing Milestones

### Milestone 1 — Backend health & rooms
```bash
curl http://localhost:3000/health
curl -X POST http://localhost:3000/api/rooms -H "Content-Type: application/json" -d '{"username":"Host"}'
curl http://localhost:3000/api/rooms/ROOM_ID
```

### Milestone 2 — Video upload & streaming
```bash
curl -X POST http://localhost:3000/api/rooms/ROOM_ID/video -F "video=@/path/to/video.mp4"
curl -I -H "Range: bytes=0-1023" http://localhost:3000/api/videos/ROOM_ID
# Expect: HTTP/1.1 206 Partial Content
```

### Milestone 3 — Socket.IO (use browser or wscat)
- Connect to `ws://localhost:3000`
- Emit `join_room` with `{ roomId, username }`
- Host emits `sync_play` / `sync_pause` / `sync_seek`
- All clients receive `playback_update`
- Emit `chat_message` with `{ content }`

### Milestone 4 — End-to-end app
1. Start backend (`npm run dev`)
2. Run Flutter on emulator or device
3. Device A: Create room → upload video → play/pause/seek
4. Device B: Join with room ID → verify sync within 500ms
5. Send chat messages on both devices

## Phase 2 TODOs (in code)

- WebRTC camera streams (signaling handlers stubbed in `backend/src/sockets/index.js`)
- FFmpeg HLS transcoding for adaptive bitrate
- S3 / cloud video storage
- Redis for multi-instance room state
- Persistent database for rooms and users
- Authentication
