const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { getAuthoritativeTime, applySyncEvent } = require('../src/services/syncService');
const { createRoom, getRoom } = require('../src/services/roomService');

describe('syncService', () => {
  describe('getAuthoritativeTime', () => {
    it('returns currentTime when paused', () => {
      const state = {
        isPlaying: false,
        currentTime: 42.5,
        playbackRate: 1,
        updatedAt: 1000,
      };
      assert.equal(getAuthoritativeTime(state, 5000), 42.5);
    });

    it('advances time while playing', () => {
      const state = {
        isPlaying: true,
        currentTime: 10,
        playbackRate: 2,
        updatedAt: 1000,
      };
      // 3 seconds elapsed at 2x rate => +6 seconds
      assert.equal(getAuthoritativeTime(state, 4000), 16);
    });
  });

  describe('applySyncEvent', () => {
    it('updates playback state and persists play event', () => {
      const { room, hostId } = createRoom('Host');
      const result = applySyncEvent(room.id, 'play', { time: 5, rate: 1.5 });

      assert.ok(result);
      assert.equal(result.playbackState.isPlaying, true);
      assert.equal(result.playbackState.currentTime, 5);
      assert.equal(result.playbackState.playbackRate, 1.5);

      const updated = getRoom(room.id);
      assert.equal(updated.playbackState.isPlaying, true);
      assert.equal(updated.hostId, hostId);
    });

    it('handles pause and seek events', () => {
      const { room } = createRoom('Host');
      applySyncEvent(room.id, 'play', { time: 0, rate: 1 });
      const paused = applySyncEvent(room.id, 'pause', { time: 12.3 });

      assert.equal(paused.playbackState.isPlaying, false);
      assert.equal(paused.playbackState.currentTime, 12.3);

      const seeked = applySyncEvent(room.id, 'seek', { time: 99 });
      assert.equal(seeked.playbackState.currentTime, 99);
    });
  });
});
