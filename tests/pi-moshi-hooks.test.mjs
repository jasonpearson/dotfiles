// node --test tests/pi-moshi-hooks.test.mjs (Node >= 24; no real Moshi or Pi calls).
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import fs from "node:fs";
import net from "node:net";
import os from "node:os";
import childProcess from "node:child_process";
import { syncBuiltinESMExports } from "node:module";
import { test } from "node:test";

let serial = 0;
const tick = () => new Promise(resolve => setImmediate(resolve));

async function harness(t, { enabled = false, disabled = false, offline = false,
  envEnabled = false, envDisabled = false, holdAcks = false, holdConnects = false } = {}) {
  const env = { ...process.env };
  process.env.TMUX = "/test-tmux.sock,123,0";
  process.env.TMUX_PANE = "%99";
  process.env.MOSHI_SOCKET_PATH = "/test-moshi.sock";
  process.env.XDG_CONFIG_HOME = "/deliberately-not-used";
  delete process.env.DOTFILES_MOSHI_DISABLED;
  delete process.env.DOTFILES_MOSHI_ENABLED;
  if (envDisabled) process.env.DOTFILES_MOSHI_DISABLED = "1";
  if (envEnabled) process.env.DOTFILES_MOSHI_ENABLED = "1";
  const connections = [], sockets = [], envelopes = [], probes = [], handlers = new Map();
  t.mock.method(os, "homedir", () => "/test home");
  t.mock.method(fs, "existsSync", path => {
    if (path === "/test home/.config/moshi/disabled") return disabled;
    assert.equal(path, "/test home/.config/moshi/enabled");
    return enabled;
  });
  t.mock.method(childProcess, "spawnSync", (...args) => {
    probes.push(args);
    return { stdout: "test-session\t1\n" };
  });
  t.mock.method(net, "createConnection", options => {
    connections.push(options);
    const socket = new EventEmitter();
    sockets.push(socket);
    let closed = false;
    const close = () => {
      if (closed) return;
      closed = true;
      socket.emit("close");
    };
    socket.connect = () => { if (!closed) socket.emit("connect"); };
    socket.ack = () => {
      if (closed) return;
      socket.emit("data", Buffer.from("{}\n"));
      close();
    };
    socket.setNoDelay = () => {};
    socket.write = data => {
      assert.equal(closed, false, "write after socket close");
      envelopes.push(JSON.parse(data));
    };
    socket.end = () => { if (!holdAcks) queueMicrotask(socket.ack); };
    socket.destroy = close;
    queueMicrotask(() => {
      if (offline) socket.emit("error", new Error("offline"));
      else if (!holdConnects) socket.connect();
    });
    return socket;
  });
  syncBuiltinESMExports();
  t.after(() => {
    t.mock.restoreAll();
    syncBuiltinESMExports();
    for (const key of Object.keys(process.env)) if (!(key in env)) delete process.env[key];
    Object.assign(process.env, env);
  });
  const { default: extension } = await import(`../agents/pi/extensions/moshi-hooks.ts?test=${++serial}`);
  extension({ on: (event, callback) => handlers.set(event, callback) });
  const ctx = {
    cwd: "/test/project", model: { name: "Test model" },
    sessionManager: { getSessionId: () => `test-${serial}`, getSessionFile: () => "" },
    getContextUsage: () => ({ percent: 25 }),
  };
  const dispatch = (name, event = {}) => handlers.get(name)?.(event, ctx);
  return {
    handlers, connections, sockets, envelopes, probes, dispatch, tick,
    enable: value => { enabled = value; },
    disable: value => { disabled = value; },
    emit: async (name, event = {}) => { await dispatch(name, event); await tick(); },
  };
}

test("disabled by default: no handlers, terminal probes, or socket connections", async t => {
  const h = await harness(t);
  assert.equal(h.handlers.size, 0);
  assert.deepEqual(h.probes, []);
  assert.deepEqual(h.connections, []);
});

test("an inherited enable environment variable cannot opt in", async t => {
  const h = await harness(t, { envEnabled: true });
  assert.equal(h.handlers.size, 0);
  await h.emit("session_start");
  await h.emit("before_agent_start", { prompt: "Private work prompt" });
  assert.deepEqual(h.probes, []);
  assert.deepEqual(h.connections, []);
});

test("the local enabled marker enables delivery", async t => {
  const h = await harness(t, { enabled: true });
  await h.emit("session_start");
  assert.equal(h.envelopes.length, 1);
});

for (const optOut of ["marker", "environment"]) {
  test(`${optOut} opt-out overrides the local opt-in`, async t => {
    const h = await harness(t, {
      enabled: true, envEnabled: true,
      disabled: optOut === "marker", envDisabled: optOut === "environment",
    });
    assert.equal(h.handlers.size, 0);
    assert.deepEqual(h.probes, []);
    assert.deepEqual(h.connections, []);
  });
}

test("enabled lifecycle preserves metadata and waits for agent_settled", async t => {
  const h = await harness(t, { enabled: true });
  assert.deepEqual(h.probes, [], "loading the extension must not spawn tmux");
  await h.emit("session_start");
  await h.emit("before_agent_start", { prompt: "Test prompt" });
  await h.emit("agent_end", { messages: [{ role: "assistant", content: [{ type: "text", text: "All done" }] }] });
  assert.equal(h.envelopes.length, 2, "agent_end alone is not completion");
  await h.emit("agent_settled");
  await h.emit("session_shutdown");
  assert.equal(h.probes.length, 1);
  assert.ok(h.connections.every(({ path }) => path === "/test-moshi.sock"));
  assert.deepEqual(h.envelopes.map(e => e.eventName), ["SessionStart", "SessionStart", "AgentEnd", "SessionEnd"]);
  assert.equal(h.envelopes[0].contextRemaining, 75);
  assert.equal(h.envelopes[0].tmuxSession, "test-session");
  assert.equal(h.envelopes[1].message, "You: Test prompt");
  assert.equal(h.envelopes[2].category, "task_complete");
  assert.equal(h.envelopes[2].title, "All done");
  assert.equal(h.envelopes[3].type, "session.closed");
});

for (const mode of ["remove opt-in", "add opt-out"]) {
  test(`${mode} mid-session stops future events`, async t => {
    const h = await harness(t, { enabled: true });
    await h.emit("session_start");
    if (mode === "remove opt-in") h.enable(false);
    else h.disable(true);
    await h.emit("before_agent_start", { prompt: "Do not forward this" });
    await h.emit("agent_end", { messages: [{ role: "assistant", content: "Private response" }] });
    await h.emit("agent_settled");
    await h.emit("session_shutdown");
    assert.equal(h.connections.length, 1);
    h.enable(true);
    h.disable(false);
    await h.emit("before_agent_start", { prompt: "Enabled again" });
    assert.equal(h.envelopes.at(-1).message, "You: Enabled again");
  });
}

test("disabling before the first event avoids terminal probes and delivery", async t => {
  const h = await harness(t, { enabled: true, envEnabled: true });
  h.enable(false);
  await h.emit("session_start");
  await h.emit("before_agent_start", { prompt: "Private work prompt" });
  await h.emit("session_shutdown");
  assert.deepEqual(h.probes, []);
  assert.deepEqual(h.connections, []);
});

test("assistant text captured while disabled is never replayed after enabling", async t => {
  const h = await harness(t, { enabled: true });
  await h.emit("agent_end", { messages: [{ role: "assistant", content: "Earlier response" }] });
  h.disable(true);
  await h.emit("agent_end", { messages: [{ role: "assistant", content: "Private work response" }] });
  h.disable(false);
  await h.emit("agent_settled");
  assert.equal(h.envelopes.at(-1).title, "Pi complete");
  assert.ok(!JSON.stringify(h.envelopes).includes("Private work response"));
});

for (const revoke of ["remove opt-in", "add opt-out", "environment disable"]) {
  const disable = h => {
    if (revoke === "remove opt-in") h.enable(false);
    else if (revoke === "add opt-out") h.disable(true);
    else process.env.DOTFILES_MOSHI_DISABLED = "1";
  };

  test(`${revoke} drops queued private data before opening another socket`, async t => {
    const h = await harness(t, { enabled: true, holdAcks: true });
    h.dispatch("session_start");
    h.dispatch("before_agent_start", { prompt: "Queued private prompt" });
    await h.tick();
    assert.equal(h.connections.length, 1);
    assert.equal(h.envelopes.length, 1);
    disable(h);
    h.sockets[0].ack();
    await h.emit("session_shutdown");
    assert.equal(h.connections.length, 1);
    assert.equal(h.envelopes.length, 1);
  });

  test(`${revoke} cancels data on a socket that has not connected yet`, async t => {
    const h = await harness(t, { enabled: true, holdConnects: true });
    h.dispatch("before_agent_start", { prompt: "Not yet connected private prompt" });
    await h.tick();
    assert.equal(h.connections.length, 1);
    assert.deepEqual(h.envelopes, []);
    disable(h);
    h.sockets[0].connect();
    await h.emit("session_shutdown");
    assert.deepEqual(h.envelopes, []);
  });
}

test("queued events wait for acknowledgements and shutdown flushes the final event", async t => {
  const h = await harness(t, { enabled: true, holdAcks: true });
  h.dispatch("session_start");
  h.dispatch("before_agent_start", { prompt: "Ordered prompt" });
  let shutdownComplete = false;
  const shutdown = h.dispatch("session_shutdown").then(() => { shutdownComplete = true; });
  await h.tick();
  assert.equal(h.connections.length, 1);
  assert.equal(shutdownComplete, false);
  h.sockets[0].ack();
  await h.tick();
  assert.equal(h.connections.length, 2);
  assert.equal(h.envelopes[1].message, "You: Ordered prompt");
  h.sockets[1].ack();
  await h.tick();
  assert.equal(h.connections.length, 3);
  assert.equal(h.envelopes[2].type, "session.closed");
  assert.equal(shutdownComplete, false);
  h.sockets[2].ack();
  await shutdown;
  assert.equal(shutdownComplete, true);
});

test("an absent daemon does not throw or forward events", async t => {
  const h = await harness(t, { enabled: true, offline: true });
  await h.emit("session_start");
  await h.emit("before_agent_start", { prompt: "Offline" });
  await h.emit("session_shutdown");
  assert.equal(h.connections.length, 3);
  assert.deepEqual(h.envelopes, []);
});
