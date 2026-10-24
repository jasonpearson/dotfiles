// node --test tests/pi-tmux-attention.test.mjs (Node >= 24; no Pi dependencies).
import assert from "node:assert/strict";
import { join } from "node:path";
import { test } from "node:test";
import extension from "../agents/pi/extensions/tmux-attention.ts";

function harness(t, { name, mode = "tui", entries = [], complete, execAttention, idle = true } = {}) {
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
  const titles = [], requests = [], attention = [], attentionCalls = [], saved = [], oscTitles = [];
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
      if (command !== "tmux") {
        attentionCalls.push([command, ...args]);
        attention.push(args.at(-1));
      } else if (args[0] === "set-option") {
        titles.push(args[1] === "-pqu" ? "" : args[5].replace(/\\;$/, ";"));
      }
      return (command !== "tmux" && execAttention ? await execAttention(command, args) : undefined)
        ?? { code: 0, killed: false, stdout: "", stderr: "" };
    },
  };
  const ctx = {
    mode, cwd: "/repos/project", model: { id: "fake" }, isIdle: () => idle,
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
  const emit = async (event, data = {}) => handlers.get(event)?.({
    type: event,
    ...(event === "message_end" ? { message: { role: "user", content: "" } } : {}),
    ...data,
  }, ctx);
  t.after(() => emit("session_shutdown"));
  return {
    titles, requests, attention, attentionCalls, saved, emit, oscTitles,
    setIdle: (value) => { idle = value; },
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

test("attention resolves the current mise selection instead of an inherited tool PATH", async (t) => {
  const h = harness(t, { name: "No model calls" });
  for (const event of ["before_agent_start", "ui_prompt_start", "agent_settled", "session_shutdown"]) {
    await h.emit(event);
  }
  assert.deepEqual(h.attentionCalls, ["working", "blocked", "done", "clear"].map(
    (state) => ["mise", "exec", "--", "tmux-attention", state],
  ));
});

for (const result of [{ code: 1, killed: false }, { code: 0, killed: true }]) {
  test(`attention retries the stable shim after mise returns ${JSON.stringify(result)}`, async (t) => {
    const h = harness(t, { execAttention: async () => result });
    await h.emit("before_agent_start");
    assert.deepEqual(h.attentionCalls, [
      ["mise", "exec", "--", "tmux-attention", "working"],
      [join(process.env.HOME ?? "", ".local/share/mise/shims/tmux-attention"), "working"],
    ]);
  });
}

test("attention spawn errors stay silent even if both executables fail", async (t) => {
  const h = harness(t, { execAttention: async () => { throw new Error("missing executable"); } });
  await h.emit("before_agent_start");
  assert.equal(h.attentionCalls.length, 2);
});

test("cancelled work becomes idle without reporting successful completion", async (t) => {
  const h = harness(t);
  await h.emit("before_agent_start");
  await h.emit("ui_prompt_start");
  await h.emit("agent_settled", { aborted: true });
  assert.deepEqual(h.attention, ["working", "blocked", "idle"]);
});

test("provider failures are reported only when settled and reset for the next run", async (t) => {
  const h = harness(t);
  await h.emit("before_agent_start");
  await h.emit("message_end", { message: { role: "assistant", stopReason: "error" } });
  await h.emit("message_end", { message: { role: "toolResult", isError: true } });
  assert.deepEqual(h.attention, ["working"]);
  await h.emit("agent_settled", { aborted: false });
  assert.deepEqual(h.attention, ["working", "failed"]);
  await h.emit("before_agent_start");
  await h.emit("agent_settled", { aborted: false });
  assert.deepEqual(h.attention, ["working", "failed", "working", "done"]);
});

test("a successful retry replaces an earlier provider failure", async (t) => {
  const h = harness(t);
  await h.emit("before_agent_start");
  await h.emit("message_end", { message: { role: "assistant", stopReason: "error" } });
  await h.emit("agent_end");
  assert.deepEqual(h.attention, ["working"]);
  await h.emit("message_end", { message: { role: "assistant", stopReason: "stop" } });
  await h.emit("agent_settled", { aborted: false });
  assert.deepEqual(h.attention, ["working", "done"]);
});

test("an aborted response is idle even on versions without the settled abort flag", async (t) => {
  const h = harness(t);
  await h.emit("before_agent_start");
  await h.emit("message_end", { message: { role: "assistant", stopReason: "aborted" } });
  await h.emit("agent_settled");
  assert.deepEqual(h.attention, ["working", "idle"]);
});

test("answering a prompt resumes active work and clears idle dialogs", async (t) => {
  const h = harness(t, { idle: false });
  await h.emit("before_agent_start");
  await h.emit("ui_prompt_start");
  await h.emit("ui_prompt_end");
  await h.emit("agent_settled", { aborted: false });
  h.setIdle(true);
  await h.emit("ui_prompt_start");
  await h.emit("ui_prompt_end");
  assert.deepEqual(h.attention, ["working", "blocked", "working", "done", "blocked", "clear"]);
});

test("interactive Pi outside tmux never updates attention or pane titles", async (t) => {
  const h = harness(t);
  delete process.env.TMUX;
  delete process.env.TMUX_PANE;
  for (const event of ["session_start", "before_agent_start", "ui_prompt_start", "ui_prompt_end", "session_shutdown"]) {
    await h.emit(event);
  }
  await h.emit("message_end", { message: { role: "assistant", stopReason: "error" } });
  await h.emit("agent_settled", { aborted: true });
  assert.deepEqual(h.attentionCalls, []);
  assert.deepEqual(h.titles, []);
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
    await h.emit("message_end", { message: { role: "assistant", stopReason: "error" } });
    await h.emit("agent_settled", { aborted: false });
    await h.emit("agent_settled", { aborted: true });
    await h.tick(300_000);
    assert.deepEqual(h.titles, []);
    assert.deepEqual(h.attention, []);
    assert.deepEqual(h.requests, []);
  });
}
