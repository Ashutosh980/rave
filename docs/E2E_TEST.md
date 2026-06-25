# Manual E2E Test Checklist

Run with two Android devices (or emulator + device) against a running backend.

## Prerequisites

```bash
cd backend && npm run dev
cd mobile && flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:3000
```

## Test cases

### 1. Room create and join
- [ ] Device A: Create room with username "Alice"
- [ ] Device A: Note room ID in app bar
- [ ] Device B: Enter same server URL, room ID, username "Bob", tap Join
- [ ] Both devices show "2 watching"

### 2. Video upload and playback
- [ ] Device A (host): Upload a local MP4
- [ ] Device B: Video appears without manual refresh
- [ ] Device A: Play, pause, seek, change playback rate
- [ ] Device B: Playback stays within ~500ms of host

### 3. Chat
- [ ] Device A sends a message → appears on Device B
- [ ] Device B replies → appears on Device A
- [ ] Rejoin: leave and re-enter → chat history preserved

### 4. Host migration
- [ ] Device A (host) exits room
- [ ] Device B: "Host" chip appears; playback controls enabled
- [ ] Device B can play/pause and other clients sync

### 5. Upload authorization
- [ ] Non-host cannot upload via app UI (no upload button)
- [ ] `curl -X POST .../video -F video=@file.mp4` without `X-Participant-Id` returns 403

### 6. Reconnect
- [ ] Toggle airplane mode on Device B briefly
- [ ] Device B rejoins automatically; video and sync resume

### 7. Server URL
- [ ] Change server URL on home screen, save, create room on self-hosted backend

### 8. Live stream (Phase 2)
- [ ] Device A (host): tap camera icon → Camera → confirm LIVE badge
- [ ] Device B: remote video appears within ~5s
- [ ] Device A: tap stop → Device B stream ends
- [ ] Repeat with Screen share (Android)
- [ ] Confirm file-upload playback still works when live stream is off

## Automated tests

```bash
cd backend && npm test
```

Covers `syncService` authoritative time, playback events, `joinRoom`, and host migration on `leaveRoom`.
