/** @typedef {Object} Participant
 * @property {string} id
 * @property {string} username
 * @property {string|null} socketId
 * @property {number} joinedAt
 */

/** @typedef {Object} PlaybackState
 * @property {boolean} isPlaying
 * @property {number} currentTime
 * @property {number} playbackRate
 * @property {number} updatedAt
 */

/** @typedef {Object} ChatMessage
 * @property {string} id
 * @property {string} username
 * @property {string} content
 * @property {number} timestamp
 */

/** @typedef {Object} Room
 * @property {string} id
 * @property {string} hostId
 * @property {string} hostUsername
 * @property {string|null} videoFilename
 * @property {number} videoVersion
 * @property {Map<string, Participant>} participants
 * @property {PlaybackState} playbackState
 * @property {ChatMessage[]} chatMessages
 * @property {number} createdAt
 */

/** @returns {PlaybackState} */
function createDefaultPlaybackState() {
  return {
    isPlaying: false,
    currentTime: 0,
    playbackRate: 1,
    updatedAt: Date.now(),
  };
}

module.exports = { createDefaultPlaybackState };
