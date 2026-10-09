// node --test tests/pi-tmux-attention.test.mjs (Node >= 24; no Pi dependencies).
import assert from "node:assert/strict";
import { test } from "node:test";
import extension from "../agents/pi/extensions/tmux-attention.ts";

function harness(t, { name, mode = "tui", entries = [], complete } = {}) {
  t.mock.timers.enable({ apis: ["setTimeout", "Date"], now: 1_000_000 });
  const env = { TMUX: process.env.TMUX, TMUX_PANE: process.env.TMUX_PANE };
  process.env.TMUX = "/private-test-socket,123,0";
  process.env.TMUX_PANE = "%99";
  t.after(() => {
    for (const [key, value] of Object.entries(env)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
  const handlers = new Map();
  const titles = [], requests = [], attention = [], saved = [], oscTitles = [];
  let sessionId = "first-session";
  const pi = {
    on: (event, callback) => handlers.set(event, callback),
    getSessionName: () => name,
    appendEntry: (customType, data) => {
      const entry = { type: "custom", customType, data };
      entries.push(entry);
      saved.push(entry);
    },
    exec: async (command, args) => {
      if (command !== "tmux") attention.push(args[0]);
      else if (args[0] === "set-option") {
        titles.push(args[1] === "-pqu" ? "" : args[5].replace(/\\;$/, ";"));
      }
    },
  };
  const ctx = {
    mode, cwd: "/repos/project", model: { id: "fake" }, isIdle: () => true,
    ui: { setTitle: (title) => oscTitles.push(title) },
    sessionManager: { getSessionId: () => sessionId, getBranch: () => entries },
    modelRegistry: {
      complete: async (...args) => {
        requests.push(args);
        return complete ? complete(...args) : { content: [{ type: "text", text: "Generated task" }] };
      },
    },
  };
  extension(pi);
  const emit = async (event) => handlers.get(event)?.({ type: event }, ctx);
  t.after(() => emit("session_shutdown"));
  return {
    titles, requests, attention, saved, emit, oscTitles,
    nativeTitle: (title) => ctx.ui.setTitle(title),
    message: (text) => entries.push({ type: "message", message: { role: "user", content: text } }),
    rename: async (value) => { name = value; await emit("session_info_changed"); },
    switchSession: async () => { sessionId = "second-session"; entries = []; await emit("session_start"); },
    tick: async (ms) => {
      t.mock.timers.tick(ms);
      // Flush the nested async completion and extension continuations.
      for (let i = 0; i < 6; i++) await Promise.resolve();
    },
  };
}

test("named sessions always use their manual name and make no summary calls", async (t) => {
  const h = harness(t, { name: "- My manual title" });
  h.message("A task");
  await h.emit("session_start");
  await h.emit("before_agent_start");
  await h.emit("agent_settled");
  await h.tick(300_000);
  assert.equal(h.titles.at(-1), "- My manual title");
  assert.equal(h.requests.length, 0);
  assert.deepEqual(h.attention, ["working", "done"]);
});

test("unnamed sessions summarize changed conversation at most every two minutes", async (t) => {
  const h = harness(t);
  await h.emit("session_start");
  await h.tick(1_000);
  assert.equal(h.titles.at(-1), "project");
  assert.equal(h.requests.length, 0);
  h.message("A task");
  await h.emit("message_end");
  await h.tick(1_000);
  assert.equal(h.titles.at(-1), "Generated task");
  assert.equal(h.requests.length, 1);
  h.message("More context");
  await h.emit("message_end");
  await h.emit("agent_settled");
  await h.tick(119_999);
  assert.equal(h.requests.length, 1);
  await h.tick(1);
  assert.equal(h.requests.length, 2);
  await h.emit("agent_settled");
  await h.tick(240_000);
  assert.equal(h.requests.length, 2, "unchanged conversation is not summarized again");
  assert.equal(h.saved[0].customType, "tmux-title-summary");
});

test("manual rename cancels and defeats a late summary result", async (t) => {
  let resolve;
  const h = harness(t, { complete: () => new Promise((done) => { resolve = done; }) });
  h.message("A task");
  await h.emit("session_start");
  await h.tick(1_000);
  await h.rename("Pinned title");
  assert.equal(h.requests[0][2].signal.aborted, true);
  resolve({ content: [{ type: "text", text: "Obsolete summary" }] });
  await h.tick(300_000);
  assert.equal(h.titles.at(-1), "Pinned title");
  assert.equal(h.saved.length, 0);
  assert.equal(h.requests.length, 1);
});

test("session switch and shutdown invalidate in-flight summaries", async (t) => {
  let resolve;
  const h = harness(t, { complete: () => new Promise((done) => { resolve = done; }) });
  h.message("Old task");
  await h.emit("session_start");
  await h.tick(1_000);
  await h.switchSession();
  resolve({ content: [{ type: "text", text: "Old session summary" }] });
  await h.tick(1_000);
  assert.equal(h.titles.at(-1), "project");
  assert.equal(h.saved.length, 0);
  h.message("New task");
  await h.emit("message_end");
  await h.tick(1_000);
  await h.emit("session_shutdown");
  resolve({ content: [{ type: "text", text: "Late shutdown summary" }] });
  await h.tick(300_000);
  assert.equal(h.titles.at(-1), "");
  assert.equal(h.saved.length, 0);
});

test("saved summary restores on resume, manual name still wins, clearing name restores summary", async (t) => {
  const h = harness(t, {
    name: "Manual name",
    entries: [{ type: "custom", customType: "tmux-title-summary",
      data: { title: "Saved task", hash: "old-hash", updatedAt: 999_000 } }],
  });
  await h.emit("session_start");
  assert.equal(h.titles.at(-1), "Manual name");
  await h.rename(undefined);
  assert.equal(h.titles.at(-1), "Saved task");
  await h.tick(300_000);
  assert.equal(h.requests.length, 0, "empty conversation needs no call");
});

test("failed summaries retain the old title and do not poll while idle", async (t) => {
  const h = harness(t, { complete: () => { throw new Error("fake provider failure"); } });
  h.message("A task");
  await h.emit("session_start");
  await h.tick(1_000);
  await h.tick(300_000);
  assert.equal(h.requests.length, 1);
  assert.equal(h.titles.at(-1), "project");
  await h.emit("message_end");
  await h.tick(1_000);
  assert.equal(h.requests.length, 2);
});

test("native startup title writes cannot replace a restored summary or manual name", async (t) => {
  const h = harness(t, {
    entries: [{ type: "custom", customType: "tmux-title-summary",
      data: { title: "Saved task", hash: "old-hash", updatedAt: 999_000 } }],
  });
  await h.emit("session_start");
  h.nativeTitle("π - project"); // Pi rebindCurrentSession runs this AFTER session_start.
  await h.tick(300_000);
  assert.equal(h.titles.at(-1), "Saved task");
  await h.rename("Manual;");
  h.nativeTitle("π - Manual; - project");
  assert.equal(h.titles.at(-1), "Manual;");
  assert.equal(h.requests.length, 0);
});

for (const mode of ["print", "json", "rpc"]) {
  test(`${mode} never changes the parent pane or makes title requests`, async (t) => {
    const h = harness(t, { mode });
    h.message("Nested task");
    for (const event of ["session_start", "before_agent_start", "ui_prompt_start", "ui_prompt_end", "agent_settled", "session_shutdown"]) {
      await h.emit(event);
    }
    await h.tick(300_000);
    assert.deepEqual(h.titles, []);
    assert.deepEqual(h.attention, []);
    assert.deepEqual(h.requests, []);
  });
}
