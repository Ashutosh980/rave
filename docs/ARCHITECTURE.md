# Rave — Phase 1 Architecture

## System Overview

Private watch-party platform: host creates a room, uploads a video, controls playback; participants join via room ID, stream the same video in sync, and chat in real time.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           WATCH PARTY SYSTEM (Phase 1)                       │
└─────────────────────────────────────────────────────────────────────────────┘

  ┌──────────────┐         HTTP REST              ┌──────────────────────────┐
  │              │  POST /api/rooms               │                          │
  │   Flutter    │  GET  /api/rooms/:id           │   Node.js + Express      │
  │   Client     │  POST /api/rooms/:id/video     │                          │
  │  (Riverpod)  │  GET  /api/videos/:roomId      │   ┌────────────────────┐ │
  │              │  (Range: bytes=start-end)      │   │  REST Controllers  │ │
  │  media_kit   │◄──────────────────────────────►│   │  room / video      │ │
  │  player      │                                │   └─────────┬──────────┘ │
  │              │         WebSocket              │             │            │
  │  Socket.IO   │  join_room, sync_*, chat     │   ┌─────────▼──────────┐ │
  │  client      │◄──────────────────────────────►│   │  Socket.IO Server  │ │
  │              │                                │   │  room/sync/chat    │ │
  └──────────────┘                                │   └─────────┬──────────┘ │
                                                  │             │            │
                                                  │   ┌─────────▼──────────┐ │
                                                  │   │  In-Memory Store     │ │
                                                  │   │  rooms, participants │ │
                                                  │   │  playback, messages  │ │
                                                  │   └─────────┬──────────┘ │
                                                  │             │            │
                                                  │   ┌─────────▼──────────┐ │
                                                  │   │  Local Video Storage │ │
                                                  │   │  ./storage/videos/   │ │
                                                  │   └────────────────────┘ │
                                                  └──────────────────────────┘

  Phase 2 (TODO): WebRTC camera streams, HLS via FFmpeg, S3, Redis pub/sub
```

## Data Flow

### Room lifecycle
1. Host calls `POST /api/rooms` → server creates room with unique ID, stores host username.
2. Host connects Socket.IO, emits `join_room` with `roomId` + `username`.
3. Participants call `GET /api/rooms/:id` (optional validation), then socket `join_room`.
4. Server adds participant, broadcasts `participant_joined`, sends `room_state` to joiner.

### Video
1. Host uploads via `POST /api/rooms/:id/video` (multipart).
2. Server saves to `storage/videos/{roomId}{ext}`, updates room `videoFilename`.
3. All clients play `GET /api/videos/:roomId` — server supports HTTP Range for seeking.

### Playback sync (host-authoritative)
1. Host emits `sync_play` | `sync_pause` | `sync_seek` | `sync_rate`.
2. Server validates sender is host, updates `playbackState`, broadcasts `playback_update`.
3. Participants apply state to media_kit player.
4. Client-side drift correction: if `|localPosition - serverPosition| > 500ms`, seek to server position.

### Chat
1. Client emits `chat_message` with `content`.
2. Server appends to room message list (cap 100), broadcasts `chat_message` to room.

## API Contracts

### REST

| Method | Path | Body | Response |
|--------|------|------|----------|
| POST | `/api/rooms` | `{ username }` | `{ roomId, hostId, createdAt }` |
| GET | `/api/rooms/:id` | — | `{ roomId, hostId, participantCount, hasVideo, playbackState }` |
| POST | `/api/rooms/:id/video` | multipart `video` | `{ filename, size }` |
| GET | `/api/videos/:roomId` | Header: `Range` | `206` partial content or `200` full |

### Socket.IO Events

**Client → Server**
| Event | Payload | Who |
|-------|---------|-----|
| `join_room` | `{ roomId, username, participantId? }` | all |
| `leave_room` | `{ roomId }` | all |
| `sync_play` | `{ time, rate? }` | host |
| `sync_pause` | `{ time }` | host |
| `sync_seek` | `{ time }` | host |
| `sync_rate` | `{ rate, time }` | host |
| `chat_message` | `{ content }` | all in room |

**Server → Client**
| Event | Payload |
|-------|---------|
| `room_state` | full room snapshot on join |
| `participant_joined` | `{ participant }` |
| `participant_left` | `{ participantId }` |
| `playback_update` | `{ playbackState, eventType }` |
| `chat_message` | `{ id, username, content, timestamp }` |
| `error` | `{ message, code }` |

## Data Models (in-memory MVP)

```typescript
Room {
  id: string
  hostId: string
  hostUsername: string
  videoFilename: string | null
  participants: Map<participantId, Participant>
  playbackState: PlaybackState
  chatMessages: ChatMessage[]  // max 100
  createdAt: number
}

Participant {
  id: string
  username: string
  socketId: string | null
  joinedAt: number
}

PlaybackState {
  isPlaying: boolean
  currentTime: number      // seconds
  playbackRate: number
  updatedAt: number        // server timestamp ms
}

ChatMessage {
  id: string
  username: string
  content: string
  timestamp: number
}
```

## MVP Tradeoffs

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Persistence | In-memory | Fast MVP; rooms lost on restart |
| Sync authority | Host-only | Simple, matches UX |
| Drift correction | Client-side 500ms threshold | Reduces server load |
| Video format | Original file + Range | No transcoding in Phase 1 |
| Auth | Username only | No accounts in Phase 1 |

## Implementation Order

1. Backend: config, models, room service + REST
2. Backend: video upload + range streaming
3. Backend: Socket.IO handlers (join, sync, chat)
4. Flutter: scaffold, models, services
5. Flutter: room UI → player → chat
