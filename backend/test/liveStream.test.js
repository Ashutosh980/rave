const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { createRoom, getRoom, setLiveStream, getLiveStream } = require('../src/services/roomService');

describe('liveStream', () => {
  it('tracks active stream on room', () => {
    const { room } = createRoom('Host');
    assert.deepEqual(getLiveStream(room), { active: false, source: null });

    setLiveStream(room.id, true, 'camera');
    const updated = getRoom(room.id);
    assert.equal(updated.liveStream.active, true);
    assert.equal(updated.liveStream.source, 'camera');
  });

  it('clears stream on stop', () => {
    const { room } = createRoom('Host');
    setLiveStream(room.id, true, 'screen');
    setLiveStream(room.id, false);

    const updated = getRoom(room.id);
    assert.equal(updated.liveStream.active, false);
    assert.equal(updated.liveStream.source, null);
  });
});
