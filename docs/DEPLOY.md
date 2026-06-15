# Deploy backend for cross-network use (WhatsApp / Drive APK sharing)

The app on your phone cannot talk to `localhost` or your home Wi‑Fi IP when friends are on **mobile data or another network**. You need **one public server** that everyone connects to.

## Option A — Quick test with ngrok (free, temporary URL)

```bash
# Terminal 1: start backend
cd backend && npm run dev

# Terminal 2: expose to internet
ngrok http 3000
```

Copy the `https://xxxx.ngrok-free.app` URL into the app **Server URL** field. Share that URL + Room ID with friends.

> ngrok URLs change every restart — fine for testing only.

## Option B — Production deploy (Railway / Render / Fly.io)

1. Push `backend/` to GitHub
2. Deploy on [Railway](https://railway.app) or [Render](https://render.com)
3. Set env: `PORT=3000`, `HOST=0.0.0.0`
4. Add persistent volume for `storage/videos/` (videos are stored on server)
5. Copy your public URL, e.g. `https://rave-api.up.railway.app`

### Build APK with server baked in (recommended for sharing)

```bash
cd mobile
flutter build apk --target-platform android-arm64 --split-per-abi \
  --dart-define=API_BASE_URL=https://rave-api.up.railway.app
```

Share the APK via WhatsApp/Drive. Everyone uses the same server automatically.

### Or let users enter server URL in the app

Users set **Server URL** once on the home screen (saved on device). Host taps **Share** in the room to send Room ID + Server URL via WhatsApp.

## How it works

```
Friend (5G, Delhi)  ──►  https://your-server.com  ◄──  You (WiFi, Mumbai)
                              │
                         video + sync + chat
```

All video streams from the **server**, not phone-to-phone. Both users need internet access to that server.

## Notes

- Large videos upload to the server — use a host with enough storage/bandwidth
- Free tiers may sleep after inactivity; first request can be slow
- For production: add HTTPS, auth, and S3 for video storage (Phase 2)
