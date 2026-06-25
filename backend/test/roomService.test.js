const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  createRoom,
  joinRoom,
  leaveRoom,
  getRoom,
  bindSocket,
} = require('../src/services/roomService');

describe('roomService', () => {
  describe('joinRoom', () => {
    it('creates a new participant when joining without existing id', () => {
      const { room } = createRoom('Alice');
      const result = joinRoom(room.id, 'Bob');

      assert.ok(!result.error);
      assert.equal(result.isReconnect, false);
      assert.equal(getRoom(room.id).participants.size, 2);
    });

    it('reconnects an existing participant', () => {
      const { room, hostId } = createRoom('Alice');
      const first = joinRoom(room.id, 'Alice', hostId);

      assert.equal(first.isReconnect, true);
      assert.equal(first.participant.id, hostId);
    });

    it('returns error for unknown room', () => {
      const result = joinRoom('NOTAROOM', 'Bob');
      assert.equal(result.error, 'ROOM_NOT_FOUND');
    });
  });

  describe('leaveRoom host migration', () => {
    it('promotes next participant when host leaves', () => {
      const { room, hostId } = createRoom('Host');
      const guest = joinRoom(room.id, 'Guest');
      bindSocket(room.id, hostId, 'socket-host');
      bindSocket(room.id, guest.participant.id, 'socket-guest');

      const result = leaveRoom(room.id, hostId);

      assert.equal(result.hostChanged, true);
      assert.equal(result.roomDeleted, false);
      assert.equal(getRoom(room.id).hostId, guest.participant.id);
      assert.equal(getRoom(room.id).hostUsername, 'Guest');
      assert.equal(getRoom(room.id).participants.size, 1);
    });

    it('deletes room when last participant leaves', () => {
      const { room, hostId } = createRoom('Solo');
      const result = leaveRoom(room.id, hostId);

      assert.equal(result.roomDeleted, true);
      assert.equal(getRoom(room.id), null);
    });
  });
});
