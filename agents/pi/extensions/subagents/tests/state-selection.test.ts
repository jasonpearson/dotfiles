import assert from "node:assert/strict";
import { test } from "node:test";
import {
	eventFileName,
	isReportDeliverable,
	isTerminalStatus,
	matchSubagents,
	tailLines,
	visibleStates,
	type SubagentState,
	type SubagentStatus,
} from "../lib/common.ts";

function state(overrides: Partial<SubagentState> & { id: string; name: string; status: SubagentStatus; parentSessionId?: string }): SubagentState {
	const { parentSessionId, ...rest } = overrides;
	return {
		version: 2,
		task: "task",
		mode: "worktree",
		createdAt: "2026-10-05T00:00:00.000Z",
		updatedAt: "2026-10-05T00:00:00.000Z",
		parent: { cwd: "/repo", sessionId: parentSessionId },
		child: { sessionId: "child", cwd: "/repo", windowName: "w" },
		...rest,
	};
}

const a = state({ id: "aaaaaaaa-1111-4111-8111-111111111111", name: "review-cli", status: "running", parentSessionId: "s1" });
const b = state({ id: "aaaaaaaa-2222-4222-8222-222222222222", name: "fix-tests", status: "done", parentSessionId: "s1" });
const c = state({ id: "bbbbbbbb-3333-4333-8333-333333333333", name: "aaaaaaaa", status: "crashed", parentSessionId: "s2" });

test("terminal statuses are the ones a scan can skip", () => {
	assert.deepEqual(
		(["starting", "running", "needs-human", "done", "failed", "cancelled", "crashed"] as SubagentStatus[]).filter(isTerminalStatus),
		["done", "failed", "cancelled", "crashed"],
	);
});

test("matchSubagents prefers exact id, then exact name, then id prefix", () => {
	assert.deepEqual(matchSubagents([a, b, c], a.id), [a]);
	assert.deepEqual(matchSubagents([a, b, c], "fix-tests"), [b]);
	// "aaaaaaaa" is both a name and an id prefix; the name wins.
	assert.deepEqual(matchSubagents([a, b, c], "aaaaaaaa"), [c]);
	assert.deepEqual(matchSubagents([a, b, c], "aaaaaaaa2222"), [b]);
	assert.deepEqual(matchSubagents([a, b, c], "AAAAAAAA-22"), [b]);
	assert.deepEqual(matchSubagents([a, b, c], "aaaaaaaa-"), [a, b]);
	assert.deepEqual(matchSubagents([a, b, c], "zzz"), []);
	assert.deepEqual(matchSubagents([a, b, c], "  "), []);
});

test("visibleStates keeps live children from any session and finished ones from this session", () => {
	assert.deepEqual(visibleStates([a, b, c], "s1"), [a, b]);
	assert.deepEqual(visibleStates([a, b, c], "s2"), [a, c]);
	assert.deepEqual(visibleStates([a, b, c], undefined), [a]);
});

test("reports written before a cancellation are still delivered", () => {
	assert.equal(isReportDeliverable({ cancelledAt: undefined }, { createdAt: "2026-10-05T01:00:00.000Z" }), true);
	assert.equal(isReportDeliverable({ cancelledAt: "2026-10-05T02:00:00.000Z" }, { createdAt: "2026-10-05T01:00:00.000Z" }), true);
	assert.equal(isReportDeliverable({ cancelledAt: "2026-10-05T02:00:00.000Z" }, { createdAt: "2026-10-05T03:00:00.000Z" }), false);
});

test("eventFileName sorts chronologically and is filesystem safe", () => {
	const first = eventFileName("2026-10-05T01:00:00.000Z", "x");
	const second = eventFileName("2026-10-05T01:00:00.001Z", "a");
	assert.ok(first < second);
	assert.doesNotMatch(first, /[:.](?!json$)/);
});

test("tailLines drops trailing blank lines and keeps the last N", () => {
	assert.equal(tailLines("a\nb\nc\n\n\n", 2), "b\nc");
	assert.equal(tailLines("only", 5), "only");
	assert.equal(tailLines("", 5), "");
});
