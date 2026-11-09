'use strict';
// Matches two players by room code and forwards their packets. It runs no game
// logic and stores nothing permanently. Frames are described in
// docs/RELAY_PROTOCOL.md.

const http = require('node:http');
const crypto = require('node:crypto');
const { WebSocketServer, WebSocket } = require('ws');

const FRAME = {
  CREATE: 1, JOIN: 2, JOINED: 3, PEER_LEFT: 4, DATA: 5, ERROR: 6, PING: 7, PONG: 8, KICK: 9,
};
const ERROR = {
  ROOM_NOT_FOUND: 1, ROOM_FULL: 2, VERSION_MISMATCH: 3, BAD_FRAME: 4, ROOM_EXPIRED: 5, SERVER_FULL: 6,
};
const HOST_ID = 1;
const FIRST_GUEST_ID = 2;
// Letters and digits that are easy to confuse when read aloud are left out.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 6;
const DATA_HEADER_BYTES = 7;

const DEFAULTS = {
  idleMs: 10 * 60 * 1000,
  sweepMs: 30 * 1000,
  heartbeatMs: 5 * 1000,
  maxRooms: 500,
  maxFrameBytes: 64 * 1024,
};

function encodeJoined(peerId, code) {
  const frame = Buffer.alloc(1 + 4 + CODE_LENGTH);
  frame[0] = FRAME.JOINED;
  frame.writeUInt32LE(peerId, 1);
  frame.write(code, 5, 'ascii');
  return frame;
}

function encodePeerLeft(peerId) {
  const frame = Buffer.alloc(5);
  frame[0] = FRAME.PEER_LEFT;
  frame.writeUInt32LE(peerId, 1);
  return frame;
}

function encodeError(code) {
  return Buffer.from([FRAME.ERROR, code]);
}

function send(socket, frame) {
  if (socket && socket.readyState === WebSocket.OPEN) {
    socket.send(frame, { binary: true });
  }
}

function createRelay(overrides = {}) {
  const options = { ...DEFAULTS, ...overrides };
  const rooms = new Map();

  const httpServer = http.createServer((request, response) => {
    if (request.url === '/health') {
      response.writeHead(200, { 'Content-Type': 'application/json' });
      response.end(JSON.stringify({ status: 'ok', rooms: rooms.size }));
      return;
    }
    response.writeHead(404);
    response.end();
  });

  const sockets = new WebSocketServer({ server: httpServer, maxPayload: options.maxFrameBytes });

  function newCode() {
    let code;
    do {
      code = '';
      for (let i = 0; i < CODE_LENGTH; i += 1) {
        code += CODE_ALPHABET[crypto.randomInt(CODE_ALPHABET.length)];
      }
    } while (rooms.has(code));
    return code;
  }

  function reject(socket, errorCode) {
    send(socket, encodeError(errorCode));
  }

  function handleCreate(socket, frame) {
    const version = frame.toString('utf8', 1);
    if (socket.room || version.length === 0) {
      reject(socket, ERROR.BAD_FRAME);
      return;
    }
    if (rooms.size >= options.maxRooms) {
      reject(socket, ERROR.SERVER_FULL);
      return;
    }
    const now = Date.now();
    const room = {
      code: newCode(),
      host_socket: socket,
      guest_socket: null,
      game_version: version,
      created_at: now,
      last_activity: now,
      next_guest_id: FIRST_GUEST_ID,
    };
    rooms.set(room.code, room);
    socket.room = room;
    socket.peerId = HOST_ID;
    send(socket, encodeJoined(HOST_ID, room.code));
  }

  function handleJoin(socket, frame) {
    if (socket.room || frame.length <= 1 + CODE_LENGTH) {
      reject(socket, ERROR.BAD_FRAME);
      return;
    }
    const code = frame.toString('ascii', 1, 1 + CODE_LENGTH).toUpperCase();
    const version = frame.toString('utf8', 1 + CODE_LENGTH);
    const room = rooms.get(code);
    if (!room) {
      reject(socket, ERROR.ROOM_NOT_FOUND);
    } else if (room.game_version !== version) {
      reject(socket, ERROR.VERSION_MISMATCH);
    } else if (room.guest_socket) {
      reject(socket, ERROR.ROOM_FULL);
    } else {
      room.guest_socket = socket;
      room.last_activity = Date.now();
      socket.room = room;
      socket.peerId = room.next_guest_id;
      room.next_guest_id += 1;
      send(socket, encodeJoined(socket.peerId, code));
      send(room.host_socket, encodeJoined(socket.peerId, code));
    }
  }

  function otherSocket(socket) {
    const { room } = socket;
    return socket === room.host_socket ? room.guest_socket : room.host_socket;
  }

  function handleData(socket, frame) {
    if (!socket.room || frame.length < DATA_HEADER_BYTES) {
      reject(socket, ERROR.BAD_FRAME);
      return;
    }
    socket.room.last_activity = Date.now();
    // The sender is stamped here, so no client can pretend to be another.
    frame.writeInt32LE(socket.peerId, 1);
    send(otherSocket(socket), frame);
  }

  function handleKick(socket, frame) {
    if (!socket.room || socket.peerId !== HOST_ID || frame.length !== 5) {
      reject(socket, ERROR.BAD_FRAME);
      return;
    }
    const guest = socket.room.guest_socket;
    if (guest && guest.peerId === frame.readUInt32LE(1)) {
      guest.close();
    }
  }

  function handleFrame(socket, frame, isBinary) {
    socket.isAlive = true;
    if (!isBinary || frame.length === 0) {
      reject(socket, ERROR.BAD_FRAME);
      return;
    }
    switch (frame[0]) {
      case FRAME.CREATE: handleCreate(socket, frame); break;
      case FRAME.JOIN: handleJoin(socket, frame); break;
      case FRAME.DATA: handleData(socket, frame); break;
      case FRAME.KICK: handleKick(socket, frame); break;
      case FRAME.PING:
        frame[0] = FRAME.PONG;
        send(socket, frame);
        break;
      default: reject(socket, ERROR.BAD_FRAME);
    }
  }

  function closeRoom(room) {
    rooms.delete(room.code);
    room.host_socket.room = null;
    if (room.guest_socket) {
      room.guest_socket.room = null;
    }
  }

  function leaveRoom(socket) {
    const { room } = socket;
    if (!room) {
      return;
    }
    if (socket === room.host_socket) {
      send(room.guest_socket, encodePeerLeft(HOST_ID));
      closeRoom(room);
    } else {
      room.guest_socket = null;
      socket.room = null;
      room.last_activity = Date.now();
      send(room.host_socket, encodePeerLeft(socket.peerId));
    }
  }

  sockets.on('connection', (socket) => {
    socket.room = null;
    socket.peerId = 0;
    socket.isAlive = true;
    socket.on('message', (frame, isBinary) => handleFrame(socket, frame, isBinary));
    socket.on('pong', () => { socket.isAlive = true; });
    socket.on('close', () => leaveRoom(socket));
    // A malformed or oversized frame must only cost that one connection.
    socket.on('error', () => socket.terminate());
  });

  function sweepIdleRooms() {
    const oldest = Date.now() - options.idleMs;
    for (const room of [...rooms.values()]) {
      if (room.last_activity < oldest) {
        const guest = room.guest_socket;
        const host = room.host_socket;
        closeRoom(room);
        for (const socket of [host, guest]) {
          if (socket) {
            reject(socket, ERROR.ROOM_EXPIRED);
            socket.close();
          }
        }
      }
    }
  }

  // A phone that loses signal never says goodbye, so silence has to count.
  function checkHeartbeats() {
    for (const socket of sockets.clients) {
      if (!socket.isAlive) {
        socket.terminate();
      } else {
        socket.isAlive = false;
        socket.ping();
      }
    }
  }

  let timers = [];

  return {
    start(port) {
      timers = [setInterval(sweepIdleRooms, options.sweepMs), setInterval(checkHeartbeats, options.heartbeatMs)];
      return new Promise((resolve) => {
        httpServer.listen(port, () => resolve(httpServer.address().port));
      });
    },
    stop() {
      timers.forEach(clearInterval);
      for (const socket of sockets.clients) {
        socket.terminate();
      }
      return new Promise((resolve) => {
        sockets.close(() => httpServer.close(() => resolve()));
      });
    },
    roomCount: () => rooms.size,
    hasRoom: (code) => rooms.has(code),
  };
}

if (require.main === module) {
  const port = Number(process.env.PORT) || 8080;
  createRelay().start(port).then((listening) => {
    console.log(`Sky Skirmish relay listening on port ${listening}`);
  });
}

module.exports = { createRelay, FRAME, ERROR, CODE_ALPHABET, CODE_LENGTH };
