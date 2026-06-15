# Deploy Rave Backend via GitHub + Railway

This guide puts your backend on a **public HTTPS URL** so anyone with the APK can join from any network.

## What you need

- GitHub account
- [Railway](https://railway.app) account (free tier works for testing)
- Git installed on your Mac

---

## Step 1 — Push code to GitHub

From the project root:

```bash
cd /Users/stoxbox/Desktop/Ashutosh/rave

git init
git add .
git commit -m "Initial commit: Rave watch-party Phase 1"

# Create repo on GitHub (replace YOUR_USERNAME)
gh repo create rave --public --source=. --remote=origin --push
```

**Without `gh` CLI:** create an empty repo at [github.com/new](https://github.com/new), then:

```bash
git remote add origin https://github.com/YOUR_USERNAME/rave.git
git branch -M main
git push -u origin main
```

---

## Step 2 — Deploy on Railway

1. Go to [railway.app](https://railway.app) → **Login with GitHub**
2. **New Project** → **Deploy from GitHub repo**
3. Select your `rave` repository
4. Railway may auto-detect the Dockerfile. If not, set:
   - **Root Directory:** leave empty (repo root)
   - **Dockerfile Path:** `backend/Dockerfile`
5. Under **Settings → Networking → Generate Domain**
6. Copy your public URL, e.g.:
   ```
   https://rave-production-a1b2.up.railway.app
   ```

### Test deployment

```bash
curl https://YOUR-RAILWAY-URL.up.railway.app/health
```

Expected: `{"status":"ok",...}`

---

## Step 3 — Build APK with your Railway URL

```bash
cd mobile

flutter build apk --target-platform android-arm64 --split-per-abi \
  --dart-define=API_BASE_URL=https://YOUR-RAILWAY-URL.up.railway.app
```

APK output:
```
mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Share this APK on WhatsApp / Drive. Friends only need the **Room ID** from the host.

---

## Step 4 — Use the app

1. Host: Create room → upload video → tap **Share** for Room ID
2. Friends: Install APK → Join room with Room ID
3. Everyone watches in sync + chat

---

## Optional — Persistent video storage

Railway’s default disk is **ephemeral** (videos lost on redeploy). For testing that’s fine.

To keep videos across restarts:

1. Railway project → your service → **Volumes**
2. Add volume mounted at `/app/storage/videos`
3. Redeploy

---

## Redeploy after code changes

```bash
git add .
git commit -m "Your change"
git push
```

Railway auto-redeploys from GitHub.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Application failed to respond` | Check Railway logs; ensure `PORT` env is set (Railway sets it automatically) |
| Socket not connecting | Use `https://` URL in app, not `http://` |
| Upload fails | Check `MAX_VIDEO_SIZE_MB` (default 2048). Free tier has limited disk |
| Health works but video 404 | Host must upload video after deploy; storage is per-server instance |

---

## Environment variables (Railway → Variables)

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | (Railway sets) | Server port |
| `HOST` | `0.0.0.0` | Bind address |
| `MAX_VIDEO_SIZE_MB` | `2048` | Max upload size |
| `VIDEO_STORAGE_DIR` | `/app/storage/videos` | Video storage path |
