'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { WebSocket } = require('ws');
const { createRelay, FRAME, ERROR, CODE_ALPHABET, CODE_LENGTH } = require('../relay');

const VERSION = '1.0.3';
const WAIT_MS = 2000;

// A test client whose frames can be awaited one at a time.
function connect(port, socketOptions = {}) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(`ws://127.0.0.1:${port}`, socketOptions);
    const queue = [];
    const waiting = [];
    socket.on('message', (data) => {
      if (waiting.length > 0) {
        waiting.shift()(data);
      } else {
        queue.push(data);
      }
    });
    socket.nextFrame = () => new Promise((resolveFrame, rejectFrame) => {
      if (queue.length > 0) {
        resolveFrame(queue.shift());
        return;
      }
      const timer = setTimeout(() => rejectFrame(new Error('no frame arrived')), WAIT_MS);
      waiting.push((data) => { clearTimeout(timer); resolveFrame(data); });
    });
    socket.hasClosed = new Promise((resolveClosed) => socket.on('close', resolveClosed));
    socket.on('open', () => resolve(socket));
    socket.on('error', reject);
  });
}

function createFrame(version = VERSION) {
  return Buffer.concat([Buffer.from([FRAME.CREATE]), Buffer.from(version)]);
}

function joinFrame(code, version = VERSION) {
  return Buffer.concat([Buffer.from([FRAME.JOIN]), Buffer.from(code), Buffer.from(version)]);
}

function dataFrame(target, channel, mode, payload) {
  const frame = Buffer.alloc(7 + payload.length);
  frame[0] = FRAME.DATA;
  frame.writeInt32LE(target, 1);
  frame[5] = channel;
  frame[6] = mode;
  payload.copy(frame, 7);
  return frame;
}

function parseJoined(frame) {
  assert.equal(frame[0], FRAME.JOINED);
  return { peerId: frame.readUInt32LE(1), code: frame.toString('ascii', 5, 5 + CODE_LENGTH) };
}

function assertError(frame, code) {
  assert.deepEqual([...frame], [FRAME.ERROR, code]);
}

function delay(ms) {
  return new Promise((resolve) => { setTimeout(resolve, ms); });
}

async function withRelay(overrides, body) {
  const relay = createRelay(overrides);
  const port = await relay.start(0);
  const sockets = [];
  const open = async (socketOptions) => {
    const socket = await connect(port, socketOptions);
    sockets.push(socket);
    return socket;
  };
  try {
    await body({ relay, port, open });
  } finally {
    sockets.forEach((socket) => socket.terminate());
    await relay.stop();
  }
}

async function openRoom(open) {
  const host = await open();
  host.send(createFrame());
  const { code } = parseJoined(await host.nextFrame());
  return { host, code };
}

async function openFullRoom(open) {
  const { host, code } = await openRoom(open);
  const guest = await open();
  guest.send(joinFrame(code));
  const joined = parseJoined(await guest.nextFrame());
  await host.nextFrame();
  return { host, guest, code, guestId: joined.peerId };
}

test('health endpoint reports status and room count', () => withRelay({}, async ({ port, open }) => {
  await openRoom(open);
  const response = await fetch(`http://127.0.0.1:${port}/health`);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: 'ok', rooms: 1 });
}));

test('other paths are not found', () => withRelay({}, async ({ port }) => {
  const response = await fetch(`http://127.0.0.1:${port}/anything`);
  assert.equal(response.status, 404);
}));

test('create gives the host peer id 1 and a valid code', () => withRelay({}, async ({ open }) => {
  const host = await open();
  host.send(createFrame());
  const { peerId, code } = parseJoined(await host.nextFrame());
  assert.equal(peerId, 1);
  assert.equal(code.length, 6);
  for (const letter of code) {
    assert.ok(CODE_ALPHABET.includes(letter), letter);
  }
}));

test('the code alphabet avoids look-alike characters', () => {
  for (const letter of '01OIL') {
    assert.ok(!CODE_ALPHABET.includes(letter), letter);
  }
});

test('joining tells both sides the guest id', () => withRelay({}, async ({ open }) => {
  const { host, code } = await openRoom(open);
  const guest = await open();
  guest.send(joinFrame(code));
  const toGuest = parseJoined(await guest.nextFrame());
  const toHost = parseJoined(await host.nextFrame());
  assert.ok(toGuest.peerId >= 2);
  assert.equal(toHost.peerId, toGuest.peerId);
  assert.equal(toGuest.code, code);
}));

test('codes are accepted in lower case', () => withRelay({}, async ({ open }) => {
  const { code } = await openRoom(open);
  const guest = await open();
  guest.send(joinFrame(code.toLowerCase()));
  assert.equal(parseJoined(await guest.nextFrame()).code, code);
}));

test('a wrong code is refused', () => withRelay({}, async ({ open }) => {
  const guest = await open();
  guest.send(joinFrame('ZZZZZZ'));
  assertError(await guest.nextFrame(), ERROR.ROOM_NOT_FOUND);
}));

test('a third player is refused', () => withRelay({}, async ({ open }) => {
  const { code } = await openFullRoom(open);
  const third = await open();
  third.send(joinFrame(code));
  assertError(await third.nextFrame(), ERROR.ROOM_FULL);
}));

test('a different game version is refused', () => withRelay({}, async ({ open }) => {
  const { code } = await openRoom(open);
  const guest = await open();
  guest.send(joinFrame(code, '0.9.0'));
  assertError(await guest.nextFrame(), ERROR.VERSION_MISMATCH);
}));

test('data reaches the other player unchanged, stamped with the sender', () => withRelay({}, async ({ open }) => {
  const { host, guest, guestId } = await openFullRoom(open);
  const payload = Buffer.from([0, 255, 1, 2, 3]);
  guest.send(dataFrame(1, 3, 2, payload));
  const atHost = await host.nextFrame();
  assert.equal(atHost[0], FRAME.DATA);
  assert.equal(atHost.readInt32LE(1), guestId);
  assert.equal(atHost[5], 3);
  assert.equal(atHost[6], 2);
  assert.deepEqual([...atHost.subarray(7)], [...payload]);
  host.send(dataFrame(guestId, 0, 0, payload));
  assert.equal((await guest.nextFrame()).readInt32LE(1), 1);
}));

test('a client cannot forge the sender id', () => withRelay({}, async ({ open }) => {
  const { host, guest, guestId } = await openFullRoom(open);
  const forged = dataFrame(1, 0, 0, Buffer.from([7]));
  forged.writeInt32LE(99, 1);
  guest.send(forged);
  assert.equal((await host.nextFrame()).readInt32LE(1), guestId);
}));

test('data before joining a room is refused', () => withRelay({}, async ({ open }) => {
  const stranger = await open();
  stranger.send(dataFrame(1, 0, 0, Buffer.from([1])));
  assertError(await stranger.nextFrame(), ERROR.BAD_FRAME);
}));

test('rooms keep traffic apart', () => withRelay({}, async ({ open }) => {
  const first = await openFullRoom(open);
  const second = await openFullRoom(open);
  first.guest.send(dataFrame(1, 0, 0, Buffer.from([11])));
  second.guest.send(dataFrame(1, 0, 0, Buffer.from([22])));
  assert.equal((await first.host.nextFrame())[7], 11);
  assert.equal((await second.host.nextFrame())[7], 22);
}));

test('ping is answered with pong and the same token', () => withRelay({}, async ({ open }) => {
  const client = await open();
  client.send(Buffer.from([FRAME.PING, 9, 8, 7, 6]));
  assert.deepEqual([...(await client.nextFrame())], [FRAME.PONG, 9, 8, 7, 6]);
}));

test('text frames and unknown types are bad frames, and the relay survives', () => withRelay({}, async ({ open }) => {
  const client = await open();
  client.send('hello');
  assertError(await client.nextFrame(), ERROR.BAD_FRAME);
  client.send(Buffer.from([200]));
  assertError(await client.nextFrame(), ERROR.BAD_FRAME);
  await openRoom(open);
}));

test('an oversized frame costs only that connection', () => withRelay({ maxFrameBytes: 64 }, async ({ open }) => {
  const client = await open();
  client.send(Buffer.alloc(1000, 1));
  await client.hasClosed;
  await openRoom(open);
}));

test('when the guest leaves the host is told and the room reopens', () => withRelay({}, async ({ open, relay }) => {
  const { host, guest, code, guestId } = await openFullRoom(open);
  guest.close();
  const left = await host.nextFrame();
  assert.equal(left[0], FRAME.PEER_LEFT);
  assert.equal(left.readUInt32LE(1), guestId);
  assert.ok(relay.hasRoom(code));
  const next = await open();
  next.send(joinFrame(code));
  assert.ok(parseJoined(await next.nextFrame()).peerId > guestId);
}));

test('when the host leaves the guest is told and the room is gone', () => withRelay({}, async ({ open, relay }) => {
  const { host, guest, code } = await openFullRoom(open);
  host.close();
  const left = await guest.nextFrame();
  assert.equal(left[0], FRAME.PEER_LEFT);
  assert.equal(left.readUInt32LE(1), 1);
  assert.equal(relay.hasRoom(code), false);
}));

test('the host can kick the guest; the guest cannot kick anyone', () => withRelay({}, async ({ open }) => {
  const { host, guest, guestId } = await openFullRoom(open);
  const kick = Buffer.alloc(5);
  kick[0] = FRAME.KICK;
  kick.writeUInt32LE(1, 1);
  guest.send(kick);
  assertError(await guest.nextFrame(), ERROR.BAD_FRAME);
  kick.writeUInt32LE(guestId, 1);
  host.send(kick);
  await guest.hasClosed;
}));

test('idle rooms are removed and their players told', () => withRelay({ idleMs: 40, sweepMs: 10 }, async ({ open, relay }) => {
  const { host, code } = await openRoom(open);
  assertError(await host.nextFrame(), ERROR.ROOM_EXPIRED);
  assert.equal(relay.hasRoom(code), false);
}));

test('traffic keeps a room alive', () => withRelay({ idleMs: 120, sweepMs: 10 }, async ({ open, relay }) => {
  const { host, guest, code, guestId } = await openFullRoom(open);
  for (let i = 0; i < 8; i += 1) {
    host.send(dataFrame(guestId, 0, 0, Buffer.from([i])));
    await guest.nextFrame();
    await delay(40);
  }
  assert.ok(relay.hasRoom(code));
}));

test('pings alone do not keep a room alive', () => withRelay({ idleMs: 60, sweepMs: 10 }, async ({ open, relay }) => {
  const { host, code } = await openRoom(open);
  for (let i = 0; i < 6; i += 1) {
    host.send(Buffer.from([FRAME.PING, 0, 0, 0, 0]));
    await delay(25);
  }
  assert.equal(relay.hasRoom(code), false);
}));

test('a player who stops answering heartbeats is dropped', () => withRelay({ heartbeatMs: 20 }, async ({ open }) => {
  const { host, code } = await openRoom(open);
  const guest = await open({ autoPong: false });
  guest.send(joinFrame(code));
  await guest.nextFrame();
  await host.nextFrame();
  const left = await host.nextFrame();
  assert.equal(left[0], FRAME.PEER_LEFT);
}));

test('a player who answers heartbeats stays', () => withRelay({ heartbeatMs: 20 }, async ({ open, relay }) => {
  const { code } = await openFullRoom(open);
  await delay(120);
  assert.ok(relay.hasRoom(code));
}));

test('the room limit is enforced', () => withRelay({ maxRooms: 1 }, async ({ open }) => {
  await openRoom(open);
  const late = await open();
  late.send(createFrame());
  assertError(await late.nextFrame(), ERROR.SERVER_FULL);
}));
