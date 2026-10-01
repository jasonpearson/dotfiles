import assert from "node:assert/strict";
import { test } from "node:test";
import { formatTaskSummary } from "../lib/common.ts";

test("prefers the explicit human-facing summary over the detailed assignment", () => {
	assert.equal(
		formatTaskSummary("Read every CLI entry point and examine initialization...", "Review the CLI and propose a simpler public API."),
		"Review the CLI and propose a simpler public API.",
	);
});

test("falls back to the assignment for calls without a summary", () => {
	assert.equal(formatTaskSummary("Review CLI behavior."), "Review CLI behavior.");
	assert.equal(formatTaskSummary("Review CLI behavior.", " \n\t "), "Review CLI behavior.");
});

test("collapses multiline text to a compact single line", () => {
	assert.equal(formatTaskSummary("\n Review\t CLI\n\nbehavior.  "), "Review CLI behavior.");
	assert.equal(formatTaskSummary("Unused task", "  Review\r\nCLI\tbehavior. "), "Review CLI behavior.");
});

test("leaves text at the length limit unchanged", () => {
	assert.equal(formatTaskSummary("a".repeat(240)), "a".repeat(240));
});

test("marks truncated task text with an ellipsis and caps output at 240 characters", () => {
	assert.equal(formatTaskSummary("a".repeat(241)), `${"a".repeat(239)}…`);
	assert.equal(formatTaskSummary("Unused task", "a".repeat(241)), `${"a".repeat(239)}…`);
});

test("does not split surrogate pairs when truncating", () => {
	const result = formatTaskSummary("a".repeat(238) + "🔎" + "bc");
	assert.equal(result, "a".repeat(238) + "🔎…");
	assert.equal(Array.from(result).length, 240);
});
