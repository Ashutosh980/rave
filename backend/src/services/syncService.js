const { getRoom } = require('./roomService');

/**
 * Computes authoritative playback position accounting for elapsed time while playing.
 * @param {import('../models/room').PlaybackState} state
 * @param {number} [now]
 */
function getAuthoritativeTime(state, now = Date.now()) {
  if (!state.isPlaying) {
    return state.currentTime;
  }
  const elapsedSec = (now - state.updatedAt) / 1000;
  return state.currentTime + elapsedSec * state.playbackRate;
}

/**
 * Updates room playback state from a host sync event.
 * @param {string} roomId
 * @param {'play'|'pause'|'seek'|'rate'} eventType
 * @param {{ time?: number, rate?: number }} payload
 */
function applySyncEvent(roomId, eventType, payload) {
  const room = getRoom(roomId);
  if (!room) return null;

  const state = room.playbackState;
  const now = Date.now();

  switch (eventType) {
    case 'play':
      state.currentTime = payload.time ?? getAuthoritativeTime(state, now);
      state.playbackRate = payload.rate ?? state.playbackRate;
      state.isPlaying = true;
      break;
    case 'pause':
      state.currentTime = payload.time ?? getAuthoritativeTime(state, now);
      state.isPlaying = false;
      break;
    case 'seek':
      state.currentTime = payload.time ?? 0;
      break;
    case 'rate':
      state.currentTime = payload.time ?? getAuthoritativeTime(state, now);
      state.playbackRate = payload.rate ?? 1;
      break;
    default:
      return null;
  }

  state.updatedAt = now;

  return {
    playbackState: { ...state },
    authoritativeTime: getAuthoritativeTime(state, now),
    eventType,
  };
}

module.exports = { getAuthoritativeTime, applySyncEvent };
