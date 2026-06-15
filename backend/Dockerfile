FROM node:20-alpine

WORKDIR /app

# Build context is repo root (see railway.toml)
COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev

COPY backend/src ./src
RUN mkdir -p storage/videos

ENV HOST=0.0.0.0
ENV NODE_ENV=production
ENV VIDEO_STORAGE_DIR=/app/storage/videos

EXPOSE 3000

CMD ["npm", "start"]
