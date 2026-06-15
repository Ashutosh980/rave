const fs = require('fs');

/**
 * Parses HTTP Range header and returns { start, end } for partial content.
 * @param {string|undefined} rangeHeader
 * @param {number} fileSize
 * @returns {{ start: number, end: number } | null}
 */
function parseRangeHeader(rangeHeader, fileSize) {
  if (!rangeHeader || !rangeHeader.startsWith('bytes=')) {
    return null;
  }

  const parts = rangeHeader.replace(/bytes=/, '').split('-');
  const start = parseInt(parts[0], 10);
  let end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;

  if (Number.isNaN(start) || start >= fileSize) {
    return null;
  }

  end = Math.min(end, fileSize - 1);
  if (end < start) {
    return null;
  }

  return { start, end };
}

/**
 * Streams a file slice with 206 Partial Content headers.
 * @param {import('express').Response} res
 * @param {string} filePath
 * @param {{ start: number, end: number }} range
 * @param {number} fileSize
 */
function streamRange(res, filePath, range, fileSize) {
  const { start, end } = range;
  const chunkSize = end - start + 1;

  res.status(206);
  res.set({
    'Content-Range': `bytes ${start}-${end}/${fileSize}`,
    'Accept-Ranges': 'bytes',
    'Content-Length': chunkSize,
    'Content-Type': 'video/mp4',
  });

  const stream = fs.createReadStream(filePath, { start, end });
  stream.pipe(res);
}

module.exports = { parseRangeHeader, streamRange };
