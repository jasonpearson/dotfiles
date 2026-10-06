import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { discoverAgents, parseAgentDefinition, parseFrontmatter, parseToolList, resolveChildTools } from "../lib/agents.ts";

test("parseFrontmatter reads scalars, comma lists, block lists, quotes, and comments", () => {
	const { frontmatter, body } = parseFrontmatter([
		"---",
		"name: scout",
		'description: "Fast recon" # trailing comment',
		"tools: read, grep",
		"extras:",
		"  - one",
		"  - two",
		"# a comment line",
		"empty:",
		"---",
		"",
		"Body text.",
		"",
	].join("\n"));
	assert.equal(frontmatter.name, "scout");
	assert.equal(frontmatter.description, "Fast recon");
	assert.equal(frontmatter.tools, "read, grep");
	assert.deepEqual(frontmatter.extras, ["one", "two"]);
	assert.equal(frontmatter.empty, "");
	assert.equal(body, "Body text.");
});

test("parseFrontmatter without a frontmatter block returns the whole content as body", () => {
	assert.deepEqual(parseFrontmatter("just text"), { frontmatter: {}, body: "just text" });
	assert.deepEqual(parseFrontmatter("---\nname: x\nno closing"), { frontmatter: {}, body: "---\nname: x\nno closing" });
});

test("parseToolList distinguishes omitted, empty, comma, and block forms", () => {
	assert.equal(parseToolList(undefined), undefined);
	assert.deepEqual(parseToolList(""), []);
	assert.deepEqual(parseToolList(" read ,grep, "), ["read", "grep"]);
	assert.deepEqual(parseToolList(["read", " ls "]), ["read", "ls"]);
});

test("parseAgentDefinition applies defaults and splits a thinking suffix off the model", () => {
	const { agent, error } = parseAgentDefinition("---\nname: worker\ndescription: Implements\nmodel: openai-codex/gpt-6.1-sol:high\n---\nPrompt.", "/x/worker/AGENT.md");
	assert.equal(error, undefined);
	assert.equal(agent?.model, "openai-codex/gpt-6.1-sol");
	assert.equal(agent?.thinking, "high");
	assert.equal(agent?.tools, undefined);
	assert.equal(agent?.mode, undefined);
	assert.equal(agent?.systemPromptMode, "replace");
	assert.equal(agent?.systemPrompt, "Prompt.");
});

test("parseAgentDefinition keeps an explicit thinking over the model suffix and validates enums", () => {
	const ok = parseAgentDefinition("---\nname: a\ndescription: d\nmodel: p/m:low\nthinking: xhigh\nmode: shared-read\nsystemPromptMode: append\n---\n", "/x/a/AGENT.md").agent;
	assert.equal(ok?.thinking, "xhigh");
	assert.equal(ok?.mode, "shared-read");
	assert.equal(ok?.systemPromptMode, "append");
	assert.match(parseAgentDefinition("---\nname: a\n---\n", "/x/a/AGENT.md").error ?? "", /name and description/);
	assert.match(parseAgentDefinition("---\nname: Bad Name\ndescription: d\n---\n", "/x/a/AGENT.md").error ?? "", /lowercase/);
	assert.match(parseAgentDefinition("---\nname: a\ndescription: d\nmode: nope\n---\n", "/x/a/AGENT.md").error ?? "", /mode must be/);
	assert.match(parseAgentDefinition("---\nname: a\ndescription: d\nsystemPromptMode: nope\n---\n", "/x/a/AGENT.md").error ?? "", /systemPromptMode/);
});

test("resolveChildTools always includes the child tools and enforces read-only shared-read", () => {
	assert.equal(resolveChildTools("worktree", undefined), undefined);
	assert.deepEqual(resolveChildTools("shared-read", undefined), ["read", "grep", "find", "ls", "subagent_ask", "subagent_report"]);
	const agent = parseAgentDefinition("---\nname: a\ndescription: d\ntools: read, subagent_report\n---\n", "/x").agent!;
	assert.deepEqual(resolveChildTools("worktree", agent), ["read", "subagent_report", "subagent_ask"]);
	const none = parseAgentDefinition("---\nname: a\ndescription: d\ntools:\n---\n", "/x").agent!;
	assert.deepEqual(resolveChildTools("worktree", none), ["subagent_ask", "subagent_report"]);
});

test("discoverAgents reads folder/AGENT.md and bare files, and reports mismatches as errors", () => {
	const dir = mkdtempSync(join(tmpdir(), "subagents-test-"));
	try {
		mkdirSync(join(dir, "scout"));
		writeFileSync(join(dir, "scout", "AGENT.md"), "---\nname: scout\ndescription: Recon\ntools: read\n---\nGo.");
		writeFileSync(join(dir, "oracle.md"), "---\nname: oracle\ndescription: Advice\n---\nThink.");
		mkdirSync(join(dir, "wrong"));
		writeFileSync(join(dir, "wrong", "AGENT.md"), "---\nname: other\ndescription: Mismatch\n---\n");
		mkdirSync(join(dir, "empty"));
		writeFileSync(join(dir, "notes.txt"), "ignored");
		const { agents, errors } = discoverAgents(dir);
		assert.deepEqual(agents.map((a) => a.name), ["oracle", "scout"]);
		assert.equal(agents[1].filePath, join(dir, "scout", "AGENT.md"));
		assert.equal(errors.length, 1);
		assert.match(errors[0], /does not match folder "wrong"/);
	} finally {
		rmSync(dir, { recursive: true, force: true });
	}
	assert.deepEqual(discoverAgents(join(dir, "missing")), { agents: [], errors: [] });
});
