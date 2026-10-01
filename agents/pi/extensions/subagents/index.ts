import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { chmod, readdir, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import {
	STATE_VERSION,
	SUBAGENT_TMUX_SESSION,
	agentRoot,
	ensureDir,
	formatTaskSummary,
	mailboxDir,
	modelPattern,
	newId,
	nowIso,
	questionsDir,
	readJson,
	repoHash,
	runDir,
	shellQuote,
	shortId,
	slugify,
	statePath,
	updateState,
	worktreePath,
	writeJsonAtomic,
	type ChildQuestion,
	type MailboxMessage,
	type SubagentMode,
	type SubagentState,
} from "./lib/common";

const childExtensionPath = fileURLToPath(new URL("./child.ts", import.meta.url));
const scanIntervalMs = 4_000;

export default function (pi: ExtensionAPI) {
	// Child Pi processes still auto-discover this global extension. Do not give
	// children the parent orchestration tools; child.ts supplies child-only tools.
	if (process.env.PI_SUBAGENT_ID) {
		return;
	}

	let scanTimer: ReturnType<typeof setInterval> | undefined;
	let scanning = false;

	const refreshStatus = async (ctx: ExtensionContext) => {
		ctx.ui.setStatus("subagents", formatFooterStatus(await listStates()));
	};

	const scanReports = async (ctx: ExtensionContext) => {
		if (scanning) return;
		scanning = true;
		try {
			for (const state of await listStates()) {
				await processQuestions(pi, ctx, state);
				if (!state.report || state.reportDeliveredAt) continue;

				if (state.report.status === "needs-human") {
					ctx.ui.notify(`Subagent ${state.name} needs human input: ${state.report.summary}`, "warning");
					await updateState(state.id, (next) => {
						next.reportDeliveredAt = nowIso();
						next.status = "needs-human";
					});
					continue;
				}

				const label = state.report.status === "done" ? "completed" : "failed";
				pi.sendMessage(
					{
						customType: "subagent-report",
						display: true,
						content: [
							`Subagent ${state.name} ${label}.`,
							`Status: ${state.report.status}`,
							`Summary: ${state.report.summary}`,
							state.report.artifacts.length > 0 ? `Artifacts:\n${state.report.artifacts.map((p) => `- ${p}`).join("\n")}` : undefined,
							state.git?.worktreePath ? `Worktree: ${state.git.worktreePath}` : undefined,
						]
							.filter(Boolean)
							.join("\n\n"),
						details: { subagent: state },
					},
					{ triggerTurn: true, deliverAs: "followUp" },
				);

				await updateState(state.id, (next) => {
					next.reportDeliveredAt = nowIso();
					next.status = state.report!.status;
				});

				if (state.report.status === "done") {
					await closeWindow(pi, state).catch(() => undefined);
				}
			}
			await refreshStatus(ctx);
		} finally {
			scanning = false;
		}
	};

	pi.on("session_start", async (_event, ctx) => {
		await ensureDir(agentRoot());
		await scanReports(ctx);
		scanTimer = setInterval(() => void scanReports(ctx), scanIntervalMs);
	});

	pi.on("agent_settled", async (_event, ctx) => {
		await scanReports(ctx);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		if (scanTimer) {
			clearInterval(scanTimer);
			scanTimer = undefined;
		}
		ctx.ui.setStatus("subagents", undefined);
	});

	pi.registerTool({
		name: "subagent_start",
		label: "Start Subagent",
		description:
			"Start an interactive Pi subagent in the dedicated pi-subagents tmux session. Creates a Git worktree by default and requires the child to report explicitly.",
		promptSnippet: "Start an interactive subagent for bounded research, review, or implementation tasks.",
		promptGuidelines: [
			"Use subagent_start for bounded delegated work that benefits from an independently inspectable Pi session.",
			"Include a brief, action-oriented summary in subagent_start so the human can see what the child is assigned to do.",
			"Do not treat subagent idle/process state as task success; wait for an explicit subagent_report result.",
		],
		parameters: Type.Object({
			task: Type.String({ description: "The bounded assignment for the child Pi session." }),
			summary: Type.Optional(Type.String({ description: "One short sentence describing what the child will do, shown to the human in the start result.", minLength: 1, maxLength: 240 })),
			name: Type.Optional(Type.String({ description: "Short human-readable name for the child." })),
			mode: Type.Optional(StringEnum(["worktree", "shared-read"] as const)),
			model: Type.Optional(Type.String({ description: "Optional child model pattern, e.g. provider/model." })),
			thinkingLevel: Type.Optional(Type.String({ description: "Optional child thinking level." })),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const state = await startSubagent(pi, ctx, {
				task: params.task,
				summary: params.summary,
				name: params.name,
				mode: (params.mode ?? "worktree") as SubagentMode,
				model: params.model,
				thinkingLevel: params.thinkingLevel,
				signal,
			});
			await refreshStatus(ctx);

			return {
				content: [
					{
						type: "text",
						text: [
							`Started subagent ${state.name} (${state.id}).`,
							`Task: ${formatTaskSummary(state.task, state.summary)}`,
							`Attach with: tmux attach -t ${SUBAGENT_TMUX_SESSION}`,
							`Window: ${state.child.windowName}`,
							state.git?.worktreePath ? `Worktree: ${state.git.worktreePath}` : `Cwd: ${state.child.cwd}`,
							state.git?.parentDirty ? "Note: parent checkout has uncommitted changes; child started from committed HEAD." : undefined,
						]
							.filter(Boolean)
							.join("\n"),
					},
				],
				details: { subagent: state },
			};
		},
	});

	pi.registerTool({
		name: "subagent_status",
		label: "Subagent Status",
		description: "List known subagents, reports, queued mailbox messages, and attach/resume hints.",
		parameters: Type.Object({ id: Type.Optional(Type.String()) }),
		async execute(_toolCallId, params) {
			const states = await listStates();
			const selected = params.id ? states.filter((state) => state.id === params.id || state.id.startsWith(params.id)) : states;
			const lines = selected.length === 0 ? [params.id ? `No subagent matched ${params.id}.` : "No subagents found."] : selected.map(formatStateSummary);
			return { content: [{ type: "text", text: lines.join("\n\n") }], details: { subagents: selected } };
		},
	});

	pi.registerTool({
		name: "subagent_send",
		label: "Send to Subagent",
		description: "Queue a literal mailbox message for a child subagent. The child accepts it only from its own extension when idle.",
		parameters: Type.Object({
			id: Type.String({ description: "Subagent id." }),
			message: Type.String({ description: "Literal message to deliver to the child." }),
		}),
		async execute(_toolCallId, params) {
			const state = await readJson<SubagentState>(statePath(params.id));
			const message: MailboxMessage = { id: newId(), text: params.message, createdAt: nowIso(), status: "queued" };
			await writeJsonAtomic(join(mailboxDir(params.id), `${message.createdAt.replace(/[:.]/g, "-")}-${message.id}.json`), message);
			return {
				content: [{ type: "text", text: `Queued message for ${state.name}. It will be accepted by the child when idle.` }],
				details: { message },
			};
		},
	});

	pi.registerTool({
		name: "subagent_resume",
		label: "Resume Subagent",
		description: "Open a new tmux window for a saved child session in its original worktree/cwd.",
		parameters: Type.Object({
			id: Type.String(),
			message: Type.Optional(Type.String({ description: "Optional initial follow-up prompt for the resumed child." })),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const state = await readJson<SubagentState>(statePath(params.id));
			const live = state.child.windowId ? await windowExists(pi, state.child.windowId) : false;
			if (live) {
				return { content: [{ type: "text", text: `${state.name} already has a live window. Attach with: tmux attach -t ${SUBAGENT_TMUX_SESSION}` }], details: { subagent: state } };
			}
			const resumed = await launchChildWindow(pi, state, params.message, signal);
			const next = await updateState(state.id, (s) => {
				s.status = s.report?.status ?? "running";
				s.child.windowId = resumed.windowId;
			});
			await refreshStatus(ctx);
			return { content: [{ type: "text", text: `Resumed ${state.name}. Attach with: tmux attach -t ${SUBAGENT_TMUX_SESSION}` }], details: { subagent: next } };
		},
	});

	pi.registerTool({
		name: "subagent_cancel",
		label: "Cancel Subagent",
		description: "Cooperatively cancel a child by sending Escape. Retains session/worktree/window by default.",
		parameters: Type.Object({
			id: Type.String(),
			closeWindow: Type.Optional(Type.Boolean({ description: "Kill the child tmux window after sending Escape. Defaults to false." })),
		}),
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const state = await updateState(params.id, (s) => {
				s.status = "cancelled";
				s.cancelledAt = nowIso();
			});
			if (state.child.windowId && (await windowExists(pi, state.child.windowId))) {
				await pi.exec("tmux", ["send-keys", "-t", state.child.windowId, "Escape"], { timeout: 1000 }).catch(() => undefined);
				if (params.closeWindow) await closeWindow(pi, state).catch(() => undefined);
			}
			await refreshStatus(ctx);
			return { content: [{ type: "text", text: `Marked ${state.name} cancelled. Worktree/session retained.` }], details: { subagent: state } };
		},
	});
}

async function startSubagent(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
	options: { task: string; summary?: string; name?: string; mode: SubagentMode; model?: string; thinkingLevel?: string; signal?: AbortSignal },
): Promise<SubagentState> {
	const id = newId();
	const name = options.name?.trim() || slugify(options.task);
	const createdAt = nowIso();
	const childSessionId = newId();
	const run = runDir(id);
	await ensureDir(run);
	await ensureDir(mailboxDir(id));
	await ensureDir(questionsDir(id));

	let cwd = ctx.cwd;
	let git: SubagentState["git"] | undefined;
	if (options.mode === "worktree") {
		const repoRoot = (await execStdout(pi, "git", ["-C", ctx.cwd, "rev-parse", "--show-toplevel"], options.signal)).trim();
		const baseCommit = (await execStdout(pi, "git", ["-C", repoRoot, "rev-parse", "HEAD"], options.signal)).trim();
		const dirty = (await execStdout(pi, "git", ["-C", repoRoot, "status", "--porcelain=v1"], options.signal)).trim().length > 0;
		const hash = repoHash(repoRoot);
		const wt = worktreePath(hash, id);
		const branch = `subagent/${slugify(name)}/${shortId(id)}`;
		await ensureDir(join(agentRoot(), "worktrees", hash));
		await execOk(pi, "git", ["-C", repoRoot, "worktree", "add", "-b", branch, wt, baseCommit], options.signal);
		cwd = wt;
		git = { repoRoot, repoHash: hash, baseCommit, parentDirty: dirty, branch, worktreePath: wt };
	}

	const state: SubagentState = {
		version: STATE_VERSION,
		id,
		name,
		task: options.task,
		summary: options.summary,
		mode: options.mode,
		status: "starting",
		createdAt,
		updatedAt: createdAt,
		parent: {
			cwd: ctx.cwd,
			sessionFile: ctx.sessionManager.getSessionFile() ?? undefined,
			sessionId: ctx.sessionManager.getSessionId?.() ?? undefined,
		},
		git,
		child: {
			sessionId: childSessionId,
			cwd,
			windowName: `${shortId(id)}-${slugify(name)}`.slice(0, 60),
			model: options.model ?? modelPattern(ctx.model),
			thinkingLevel: options.thinkingLevel ?? ctx.thinkingLevel,
		},
	};
	await writeJsonAtomic(statePath(id), state);

	const launched = await launchChildWindow(pi, state, undefined, options.signal);
	return updateState(id, (s) => {
		s.status = "running";
		s.child.windowId = launched.windowId;
	});
}

async function launchChildWindow(pi: ExtensionAPI, state: SubagentState, followUp?: string, signal?: AbortSignal): Promise<{ windowId: string }> {
	const run = runDir(state.id);
	const promptPath = join(run, followUp ? "resume-prompt.md" : "initial-prompt.md");
	await writeFile(promptPath, followUp ?? buildInitialPrompt(state), { mode: 0o600 });

	const scriptPath = join(run, followUp ? "resume.sh" : "launch.sh");
	const args = [
		"pi",
		"--session-id",
		state.child.sessionId,
		"--name",
		`subagent:${state.name}`,
		"-e",
		childExtensionPath,
	];
	if (state.child.model) args.push("--model", state.child.model);
	if (state.child.thinkingLevel) args.push("--thinking", state.child.thinkingLevel);
	args.push("--", `@${promptPath}`);

	await writeFile(
		scriptPath,
		[
			"#!/usr/bin/env bash",
			"set -euo pipefail",
			`export PI_SUBAGENT_ID=${shellQuote(state.id)}`,
			`export PI_SUBAGENT_RUN_DIR=${shellQuote(run)}`,
			`export PI_SUBAGENT_PARENT_CWD=${shellQuote(state.parent.cwd)}`,
			`cd ${shellQuote(state.child.cwd)}`,
			`exec ${args.map(shellQuote).join(" ")}`,
			"",
		].join("\n"),
		{ mode: 0o700 },
	);
	await chmod(scriptPath, 0o700);

	const command = `bash ${shellQuote(scriptPath)}`;
	const has = await hasTmuxSession(pi);
	const tmuxArgs = has
		? ["new-window", "-d", "-P", "-F", "#{window_id}", "-t", `${SUBAGENT_TMUX_SESSION}:`, "-n", state.child.windowName, "-c", state.child.cwd, command]
		: ["new-session", "-d", "-P", "-F", "#{window_id}", "-s", SUBAGENT_TMUX_SESSION, "-n", state.child.windowName, "-c", state.child.cwd, command];
	const windowId = (await execStdout(pi, "tmux", tmuxArgs, signal)).trim();
	return { windowId };
}

function buildInitialPrompt(state: SubagentState): string {
	return [
		"You are a Pi subagent running in an interactive tmux window.",
		"",
		"Your assignment is bounded. Complete only this assignment and report explicitly when you are done, blocked, or failed.",
		"",
		"<assignment>",
		state.task,
		"</assignment>",
		"",
		"Subagent contract:",
		"- You are inspectable by the human in tmux session `pi-subagents`.",
		"- Use `subagent_ask` for mid-task questions that need human input.",
		"- Use `subagent_report` exactly once for the terminal outcome: `done`, `failed`, or `needs-human`.",
		"- Do not treat being idle as completion; call `subagent_report` when the assignment has an outcome.",
		"- Do not merge, push, delete, clean, or retire your worktree/session.",
		"- Do not commit unless the assignment explicitly asks you to commit.",
		state.git?.worktreePath
			? `- You are working in an isolated Git worktree at ${state.git.worktreePath}, branch ${state.git.branch}, based on ${state.git.baseCommit}.`
			: "- You are using the parent checkout in shared-read mode; avoid file mutations unless explicitly asked.",
		"- Include changed files, validation performed, and artifact paths in your final report.",
		"",
	].join("\n");
}

async function listStates(): Promise<SubagentState[]> {
	const runsRoot = join(agentRoot(), "runs");
	if (!existsSync(runsRoot)) return [];
	const entries = await readdir(runsRoot, { withFileTypes: true });
	const states: SubagentState[] = [];
	for (const entry of entries) {
		if (!entry.isDirectory()) continue;
		const path = statePath(entry.name);
		if (!existsSync(path)) continue;
		try {
			states.push(await readJson<SubagentState>(path));
		} catch {
			// Ignore malformed partial state files.
		}
	}
	return states.sort((a, b) => a.createdAt.localeCompare(b.createdAt));
}

function formatStateSummary(state: SubagentState): string {
	return [
		`${state.name} (${state.id})`,
		`status: ${state.status}`,
		`window: ${state.child.windowName}${state.child.windowId ? ` ${state.child.windowId}` : ""}`,
		`attach: tmux attach -t ${SUBAGENT_TMUX_SESSION}`,
		state.git?.worktreePath ? `worktree: ${state.git.worktreePath}` : `cwd: ${state.child.cwd}`,
		state.report ? `report: ${state.report.status} — ${state.report.summary}` : "report: none",
	].join("\n");
}

function formatFooterStatus(states: SubagentState[]): string | undefined {
	if (states.length === 0) return undefined;

	const counts = new Map<string, number>();
	for (const state of states) {
		const label = state.status === "needs-human" ? "blocked" : state.status;
		counts.set(label, (counts.get(label) ?? 0) + 1);
	}

	const parts = ["starting", "running", "blocked", "done", "failed", "cancelled", "crashed"]
		.map((status) => {
			const count = counts.get(status) ?? 0;
			return count > 0 ? `${count} ${status}` : undefined;
		})
		.filter(Boolean);

	return parts.length > 0 ? `subagents: ${parts.join(" · ")}` : undefined;
}

async function processQuestions(pi: ExtensionAPI, ctx: ExtensionContext, state: SubagentState): Promise<void> {
	const dir = questionsDir(state.id);
	if (!existsSync(dir)) return;
	for (const file of await readdir(dir)) {
		if (!file.endsWith(".json")) continue;
		const path = join(dir, file);
		const question = await readJson<ChildQuestion>(path).catch(() => undefined);
		if (!question || question.notifiedAt) continue;
		ctx.ui.notify(`Subagent ${state.name} asks: ${question.question}`, "warning");
		question.notifiedAt = nowIso();
		await writeJsonAtomic(path, question);
		await updateState(state.id, (s) => {
			s.status = "needs-human";
			s.lastQuestionAt = question.createdAt;
		});
	}
}

async function hasTmuxSession(pi: ExtensionAPI): Promise<boolean> {
	const result = await pi.exec("tmux", ["has-session", "-t", SUBAGENT_TMUX_SESSION], { timeout: 1000 }).catch(() => ({ code: 1 }));
	return result.code === 0;
}

async function windowExists(pi: ExtensionAPI, windowId: string): Promise<boolean> {
	const result = await pi.exec("tmux", ["list-windows", "-t", SUBAGENT_TMUX_SESSION, "-F", "#{window_id}"], { timeout: 1000 }).catch(() => ({ code: 1, stdout: "" }));
	return result.code === 0 && result.stdout.split(/\r?\n/).includes(windowId);
}

async function closeWindow(pi: ExtensionAPI, state: SubagentState): Promise<void> {
	if (!state.child.windowId) return;
	if (!(await windowExists(pi, state.child.windowId))) return;
	await pi.exec("tmux", ["kill-window", "-t", state.child.windowId], { timeout: 1000 });
}

async function execStdout(pi: Pick<ExtensionAPI, "exec">, command: string, args: string[], signal?: AbortSignal): Promise<string> {
	const result = await pi.exec(command, args, { timeout: 30_000, signal });
	if (result.code !== 0) {
		throw new Error(`${command} ${args.join(" ")} failed: ${result.stderr || result.stdout}`);
	}
	return result.stdout;
}

async function execOk(pi: Pick<ExtensionAPI, "exec">, command: string, args: string[], signal?: AbortSignal): Promise<void> {
	await execStdout(pi, command, args, signal);
}
