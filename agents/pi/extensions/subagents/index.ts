import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { chmod, readdir, rm, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { basename, join } from "node:path";
import { CHILD_TOOLS, discoverAgents, formatAgentCatalog, resolveChildTools, type AgentDefinition } from "./lib/agents";
import { tmuxAttention } from "./lib/attention";
import {
	STATE_VERSION,
	SUBAGENT_TMUX_SESSION,
	agentRoot,
	cancelPath,
	childInfoPath,
	crashLogPath,
	ensureDir,
	eventFileName,
	formatTaskSummary,
	isReportDeliverable,
	isTerminalStatus,
	mailboxDir,
	matchSubagents,
	modelPattern,
	newId,
	nowIso,
	openQuestions,
	questionsDir,
	readJson,
	repoHash,
	reportsDir,
	runDir,
	shellQuote,
	shortId,
	slugify,
	statePath,
	tailLines,
	undeliveredQuestions,
	updateState,
	visibleStates,
	worktreePath,
	writeJsonAtomic,
	type CancelMarker,
	type ChildInfo,
	type ChildQuestion,
	type MailboxMessage,
	type SubagentMode,
	type SubagentReport,
	type SubagentState,
} from "./lib/common";

const childExtensionPath = fileURLToPath(new URL("./child.ts", import.meta.url));
const scanIntervalMs = 4_000;
const crashLogLines = 200;
const crashReportLines = 25;
// How long one "Subagent updates above." wake covers later notices.
const wakeReservationMs = 10_000;
// Let the global tmux-attention extension mark the parent pane first, then override.
const parentAttentionDelayMs = 500;
const wakeMessage = "Subagent updates above.";

type WindowInspection = { exists: boolean; dead: boolean; exitCode?: number };
type Notice = { customType: string; content: string; details: unknown };

export default function (pi: ExtensionAPI) {
	// Child Pi processes still auto-discover this global extension. Do not give
	// children the parent orchestration tools; child.ts supplies child-only tools.
	if (process.env.PI_SUBAGENT_ID) {
		return;
	}

	// Discovered once per load so the agent enum in subagent_start is stable for
	// the provider's prompt cache. New or edited agent files need /reload.
	const discovery = discoverAgents();
	const agentNames = discovery.agents.map((agent) => agent.name);

	let scanTimer: ReturnType<typeof setInterval> | undefined;
	let scanning = false;
	let wakePending = false;
	let wakeTimer: ReturnType<typeof setTimeout> | undefined;

	const currentSessionId = (ctx: ExtensionContext) => ctx.sessionManager.getSessionId();

	const refreshStatus = async (ctx: ExtensionContext) => {
		ctx.ui.setStatus("subagents", formatFooterStatus(visibleStates(await listStates(), currentSessionId(ctx))));
	};

	/**
	 * Deliver a notice to the parent model. A busy parent gets it as a follow-up
	 * after the current turn. An idle parent gets the notice appended without a
	 * turn, then one short user message starts a normal run; a run triggered by
	 * sendMessage itself skips before_agent_start, which drops extension prompt
	 * sections and churns the provider's prompt cache. One wake covers every
	 * notice appended within the reservation window.
	 */
	const wakeParent = (ctx: ExtensionContext, notice: Notice) => {
		const message = { ...notice, display: true as const };
		if (!ctx.isIdle()) {
			pi.sendMessage(message, { triggerTurn: true, deliverAs: "followUp" });
			return;
		}
		pi.sendMessage(message, { triggerTurn: false });
		if (wakePending) return;
		wakePending = true;
		wakeTimer = setTimeout(() => {
			wakePending = false;
		}, wakeReservationMs);
		pi.sendUserMessage(wakeMessage, { deliverAs: "steer" });
	};

	const scanReports = async (ctx: ExtensionContext) => {
		if (scanning) return;
		scanning = true;
		try {
			let humanNeeded = false;
			for (const state of await listStates()) {
				if (isTerminalStatus(state.status)) continue;
				const needs = await processQuestions(pi, ctx, state, wakeParent);
				const delivered = await processReports(pi, ctx, state, wakeParent);
				if (!delivered) await detectExit(pi, ctx, state, wakeParent);
				humanNeeded ||= needs;
			}
			await updateParentAttention(pi, ctx, humanNeeded);
			await refreshStatus(ctx);
		} finally {
			scanning = false;
		}
	};

	pi.on("session_start", async (_event, ctx) => {
		await ensureDir(agentRoot());
		for (const error of discovery.errors) ctx.ui.notify(`Subagent definition skipped: ${error}`, "warning");
		await scanReports(ctx);
		scanTimer = setInterval(() => void scanReports(ctx), scanIntervalMs);
	});

	pi.on("agent_start", async () => {
		wakePending = false;
		if (wakeTimer) {
			clearTimeout(wakeTimer);
			wakeTimer = undefined;
		}
	});

	pi.on("agent_settled", async (_event, ctx) => {
		await scanReports(ctx);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		if (scanTimer) {
			clearInterval(scanTimer);
			scanTimer = undefined;
		}
		if (wakeTimer) {
			clearTimeout(wakeTimer);
			wakeTimer = undefined;
		}
		ctx.ui.setStatus("subagents", undefined);
	});

	pi.registerTool({
		name: "subagent_start",
		label: "Start Subagent",
		description: [
			"Start an interactive Pi subagent in the dedicated pi-subagents tmux session. Creates a Git worktree by default and requires the child to report explicitly.",
			`Agents: ${formatAgentCatalog(discovery.agents)}.`,
			"An agent sets the child's system prompt, tool allowlist, model, and default mode; omit it for a generic child with Pi's default prompt.",
		].join(" "),
		promptSnippet: "Start an interactive subagent for bounded research, review, or implementation tasks.",
		promptGuidelines: [
			"Use subagent_start for bounded delegated work that benefits from an independently inspectable Pi session.",
			"Pick the agent whose description matches the work; call subagent_agents to read a definition before choosing when unsure.",
			"Include a brief, action-oriented summary in subagent_start so the human can see what the child is assigned to do.",
			"Do not treat subagent idle/process state as task success; wait for an explicit subagent_report result.",
		],
		parameters: Type.Object({
			task: Type.String({ description: "The bounded assignment for the child Pi session." }),
			agent:
				agentNames.length > 0
					? Type.Optional(StringEnum(agentNames as [string, ...string[]], { description: "Agent definition to start the child with." }))
					: Type.Optional(Type.String({ description: "No agent definitions were found in ~/.pi/agent/agents; leave unset." })),
			summary: Type.Optional(Type.String({ description: "One short sentence describing what the child will do, shown to the human in the start result.", minLength: 1, maxLength: 240 })),
			name: Type.Optional(Type.String({ description: "Short human-readable name for the child." })),
			mode: Type.Optional(StringEnum(["worktree", "shared-read"] as const, { description: "Overrides the agent's default. shared-read without an agent is enforced read-only." })),
			model: Type.Optional(Type.String({ description: "Optional child model pattern, e.g. provider/model. Overrides the agent's model." })),
			thinkingLevel: Type.Optional(Type.String({ description: "Optional child thinking level. Overrides the agent's level." })),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const agent = params.agent ? resolveAgent(params.agent) : undefined;
			const state = await startSubagent(pi, ctx, {
				task: params.task,
				summary: params.summary,
				name: params.name,
				agent,
				mode: (params.mode ?? agent?.mode ?? "worktree") as SubagentMode,
				model: params.model ?? agent?.model,
				thinkingLevel: params.thinkingLevel ?? agent?.thinking,
				signal,
			});
			await refreshStatus(ctx);

			return {
				content: [
					{
						type: "text",
						text: [
							`Started subagent ${state.name} (${state.id})${agent ? ` as ${agent.name}` : ""}.`,
							`Task: ${formatTaskSummary(state.task, state.summary)}`,
							`Attach with: tmux attach -t ${SUBAGENT_TMUX_SESSION}`,
							`Window: ${state.child.windowName}`,
							state.git?.worktreePath ? `Worktree: ${state.git.worktreePath}` : `Cwd: ${state.child.cwd}`,
							state.child.tools ? `Tools: ${state.child.tools.join(", ")}` : undefined,
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
		name: "subagent_agents",
		label: "Subagent Definitions",
		description: "List the agent definitions available to subagent_start, or show one definition in full including its system prompt.",
		parameters: Type.Object({
			name: Type.Optional(Type.String({ description: "Agent name to show in full." })),
		}),
		async execute(_toolCallId, params) {
			// Re-read so edits made since load are visible here, even though the
			// subagent_start enum only refreshes on /reload.
			const current = discoverAgents();
			if (params.name) {
				const agent = current.agents.find((candidate) => candidate.name === params.name);
				if (!agent) throw new Error(`No agent named "${params.name}". Known: ${current.agents.map((a) => a.name).join(", ") || "none"}.`);
				return {
					content: [{ type: "text", text: [formatAgentSummary(agent), "", "System prompt:", agent.systemPrompt || "(empty)"].join("\n") }],
					details: { agent },
				};
			}
			const lines = current.agents.length === 0 ? ["No agent definitions found in ~/.pi/agent/agents."] : current.agents.map(formatAgentSummary);
			if (current.errors.length > 0) lines.push("", `Skipped: ${current.errors.join("; ")}`);
			if (current.agents.map((a) => a.name).join(",") !== agentNames.join(",")) lines.push("", "Note: definitions changed since load; run /reload so subagent_start accepts the new names.");
			return { content: [{ type: "text", text: lines.join("\n\n") }], details: { agents: current.agents, errors: current.errors } };
		},
	});

	pi.registerTool({
		name: "subagent_status",
		label: "Subagent Status",
		description: "List known subagents, reports, open questions, and attach/resume hints. By default lists live children plus finished children from this session.",
		parameters: Type.Object({
			id: Type.Optional(Type.String({ description: "Subagent id, id prefix, or name." })),
			all: Type.Optional(Type.Boolean({ description: "Include finished children from other parent sessions." })),
		}),
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const states = await listStates();
			const selected = params.id ? matchSubagents(states, params.id) : params.all ? states : visibleStates(states, currentSessionId(ctx));
			const lines: string[] = [];
			for (const state of selected) lines.push(await formatStateSummary(state));
			if (lines.length === 0) lines.push(params.id ? `No subagent matched ${params.id}.` : "No subagents found.");
			return { content: [{ type: "text", text: lines.join("\n\n") }], details: { subagents: selected } };
		},
	});

	pi.registerTool({
		name: "subagent_send",
		label: "Send to Subagent",
		description:
			"Queue a literal mailbox message for a child subagent, delivered as a user message when the child is idle. Pass replyTo to answer a question the child asked; a question the human already answered in the child's window is refused.",
		parameters: Type.Object({
			id: Type.String({ description: "Subagent id, id prefix, or name." }),
			message: Type.String({ description: "Literal message to deliver to the child." }),
			replyTo: Type.Optional(Type.String({ description: "Question id this message answers." })),
		}),
		async execute(_toolCallId, params) {
			const state = await resolveSubagent(params.id);
			const run = runDir(state.id);
			if (params.replyTo) {
				const question = (await readQuestions(state)).find((q) => q.id === params.replyTo || q.id.startsWith(params.replyTo!));
				if (!question) throw new Error(`${state.name} has no question with id ${params.replyTo}.`);
				if (question.answeredAt) {
					throw new Error(
						`That question was already answered ${question.answeredBy === "window" ? "by the human in the child's window" : "by a mailbox reply"} at ${question.answeredAt}. Send without replyTo if you still want to deliver this message.`,
					);
				}
			}
			const message: MailboxMessage = { id: newId(), text: params.message, createdAt: nowIso(), status: "queued", replyTo: params.replyTo };
			await writeJsonAtomic(join(mailboxDir(run), eventFileName(message.createdAt, message.id)), message);
			const window = state.child.windowId ? await inspectWindow(pi, state.child.windowId) : { exists: false, dead: false };
			const live = window.exists && !window.dead && !isTerminalStatus(state.status);
			return {
				content: [
					{
						type: "text",
						text: live
							? `Queued ${params.replyTo ? "reply" : "message"} for ${state.name}. It will be accepted by the child when idle.`
							: `Queued ${params.replyTo ? "reply" : "message"} for ${state.name}, but its Pi process is not running (status: ${state.status}). Use subagent_resume to start it; the queued message is delivered on startup.`,
					},
				],
				details: { message, live },
			};
		},
	});

	pi.registerTool({
		name: "subagent_resume",
		label: "Resume Subagent",
		description: "Open a new tmux window for a saved child session in its original worktree/cwd. Archives any earlier report so the resumed child can report again.",
		parameters: Type.Object({
			id: Type.String({ description: "Subagent id, id prefix, or name." }),
			message: Type.Optional(Type.String({ description: "Optional initial follow-up prompt for the resumed child." })),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const state = await resolveSubagent(params.id);
			const window = state.child.windowId ? await inspectWindow(pi, state.child.windowId) : { exists: false, dead: false };
			if (window.exists && !window.dead) {
				return { content: [{ type: "text", text: `${state.name} already has a live window. Attach with: tmux attach -t ${SUBAGENT_TMUX_SESSION}` }], details: { subagent: state } };
			}
			if (window.exists) await closeWindow(pi, state).catch(() => undefined);
			await rm(cancelPath(runDir(state.id)), { force: true });

			const resumed = await launchChildWindow(pi, state, params.message, signal);
			const next = await updateState(state.id, (s) => {
				if (s.report) s.reports = [...(s.reports ?? []), s.report];
				delete s.report;
				delete s.reportDeliveredAt;
				delete s.exit;
				delete s.error;
				delete s.cancelledAt;
				s.status = "running";
				s.child.windowId = resumed.windowId;
			});
			await refreshStatus(ctx);
			return { content: [{ type: "text", text: `Resumed ${state.name}. Attach with: tmux attach -t ${SUBAGENT_TMUX_SESSION}` }], details: { subagent: next } };
		},
	});

	pi.registerTool({
		name: "subagent_cancel",
		label: "Cancel Subagent",
		description: "Cancel a child: writes a cancel marker the child honors (aborts its turn, stops accepting mailbox messages, refuses further reports) and sends Escape. Retains session/worktree/window by default.",
		parameters: Type.Object({
			id: Type.String({ description: "Subagent id, id prefix, or name." }),
			reason: Type.Optional(Type.String({ description: "Why the child is being cancelled; recorded for the human." })),
			closeWindow: Type.Optional(Type.Boolean({ description: "Kill the child tmux window after cancelling. Defaults to false." })),
		}),
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const resolved = await resolveSubagent(params.id);
			const cancelledAt = nowIso();
			const marker: CancelMarker = { createdAt: cancelledAt, reason: params.reason };
			await writeJsonAtomic(cancelPath(runDir(resolved.id)), marker);
			const state = await updateState(resolved.id, (s) => {
				s.status = "cancelled";
				s.cancelledAt = cancelledAt;
			});
			const window = state.child.windowId ? await inspectWindow(pi, state.child.windowId) : { exists: false, dead: false };
			if (window.exists && !window.dead) {
				await pi.exec("tmux", ["send-keys", "-t", state.child.windowId!, "Escape"], { timeout: 1000 }).catch(() => undefined);
			}
			if (params.closeWindow) await closeWindow(pi, state).catch(() => undefined);
			await refreshStatus(ctx);
			return { content: [{ type: "text", text: `Marked ${state.name} cancelled. Worktree/session retained.` }], details: { subagent: state } };
		},
	});

	function resolveAgent(name: string): AgentDefinition {
		// Read the definition fresh so prompt edits apply without a reload.
		const current = discoverAgents();
		const agent = current.agents.find((candidate) => candidate.name === name);
		if (!agent) throw new Error(`No agent named "${name}". Known: ${current.agents.map((a) => a.name).join(", ") || "none"}.`);
		return agent;
	}
}

async function startSubagent(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
	options: { task: string; summary?: string; name?: string; agent?: AgentDefinition; mode: SubagentMode; model?: string; thinkingLevel?: string; signal?: AbortSignal },
): Promise<SubagentState> {
	const id = newId();
	const name = options.name?.trim() || slugify(options.task);
	const createdAt = nowIso();
	const childSessionId = newId();
	const run = runDir(id);
	await ensureDir(run);
	await ensureDir(mailboxDir(run));
	await ensureDir(questionsDir(run));
	await ensureDir(reportsDir(run));

	let cwd = ctx.cwd;
	let git: SubagentState["git"] | undefined;
	let stateWritten = false;

	try {
		if (options.mode === "worktree") {
			const repoRoot = (await execStdout(pi, "git", ["-C", ctx.cwd, "rev-parse", "--show-toplevel"], options.signal)).trim();
			const baseCommit = (await execStdout(pi, "git", ["-C", repoRoot, "rev-parse", "HEAD"], options.signal)).trim();
			const dirty = (await execStdout(pi, "git", ["-C", repoRoot, "status", "--porcelain=v1"], options.signal)).trim().length > 0;
			const hash = repoHash(repoRoot);
			const wt = worktreePath(hash, id);
			const branch = `subagent/${slugify(name)}/${shortId(id)}`;
			await ensureDir(join(agentRoot(), "worktrees", hash));
			// Record intent before creating the worktree so cleanup knows what to remove.
			git = { repoRoot, repoHash: hash, baseCommit, parentDirty: dirty, branch, worktreePath: wt };
			await execOk(pi, "git", ["-C", repoRoot, "worktree", "add", "-b", branch, wt, baseCommit], options.signal);
			cwd = wt;
		}

		const state: SubagentState = {
			version: STATE_VERSION,
			id,
			name,
			task: options.task,
			summary: options.summary,
			mode: options.mode,
			agent: options.agent ? { name: options.agent.name, file: options.agent.filePath } : undefined,
			status: "starting",
			createdAt,
			updatedAt: createdAt,
			parent: {
				cwd: ctx.cwd,
				sessionFile: ctx.sessionManager.getSessionFile(),
				sessionId: ctx.sessionManager.getSessionId(),
			},
			git,
			child: {
				sessionId: childSessionId,
				cwd,
				windowName: `${options.agent?.name ?? "pi"}-${slugify(name, "task").slice(0, 32)}-${shortId(id)}`,
				model: options.model ?? modelPattern(ctx.model),
				thinkingLevel: options.thinkingLevel ?? ctx.thinkingLevel,
				tools: resolveChildTools(options.mode, options.agent),
				systemPromptMode: options.agent?.systemPromptMode ?? "append",
				pi: getPiInvocation(),
			},
		};
		await writeJsonAtomic(statePath(id), state);
		stateWritten = true;

		const launched = await launchChildWindow(pi, state, undefined, options.signal);
		return await updateState(id, (s) => {
			s.status = "running";
			s.child.windowId = launched.windowId;
		});
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		await cleanupFailedStart(pi, git).catch(() => undefined);
		if (stateWritten) {
			await updateState(id, (s) => {
				s.status = "failed";
				s.error = `launch failed: ${message}`;
				delete s.git;
			}).catch(() => undefined);
		} else {
			await rm(run, { recursive: true, force: true }).catch(() => undefined);
		}
		throw new Error(`Failed to start subagent ${name}: ${message}`);
	}
}

async function cleanupFailedStart(pi: ExtensionAPI, git: SubagentState["git"] | undefined): Promise<void> {
	if (!git?.worktreePath) return;
	if (existsSync(git.worktreePath)) {
		await pi.exec("git", ["-C", git.repoRoot, "worktree", "remove", "--force", git.worktreePath], { timeout: 30_000 }).catch(() => undefined);
	}
	await pi.exec("git", ["-C", git.repoRoot, "worktree", "prune"], { timeout: 30_000 }).catch(() => undefined);
	if (git.branch) {
		await pi.exec("git", ["-C", git.repoRoot, "branch", "-D", git.branch], { timeout: 30_000 }).catch(() => undefined);
	}
}

/**
 * Launch the child with the same Pi binary as the parent rather than whatever
 * `pi` resolves to on PATH inside a fresh tmux window. Mirrors the upstream
 * subagent example: a compiled binary reports itself as execPath, while a
 * node/bun runtime needs the entry script passed explicitly.
 */
function getPiInvocation(): { command: string; args: string[] } {
	const currentScript = process.argv[1];
	const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
	if (currentScript && !isBunVirtualScript && existsSync(currentScript)) {
		return { command: process.execPath, args: [currentScript] };
	}
	const execName = basename(process.execPath).toLowerCase();
	if (!/^(node|bun)(\.exe)?$/.test(execName)) {
		return { command: process.execPath, args: [] };
	}
	return { command: "pi", args: [] };
}

async function launchChildWindow(pi: ExtensionAPI, state: SubagentState, followUp?: string, signal?: AbortSignal): Promise<{ windowId: string }> {
	const run = runDir(state.id);
	const promptPath = join(run, followUp ? "resume-prompt.md" : "initial-prompt.md");
	await writeFile(promptPath, followUp ?? buildInitialPrompt(state), { mode: 0o600 });

	// The contract and any agent persona live in the system prompt so they
	// stay authoritative across resumes. Regenerated on every launch so agent
	// file edits apply; a missing agent file keeps the last generated copy.
	const systemPromptPath = join(run, "system-prompt.md");
	const agent = state.agent ? discoverAgents().agents.find((candidate) => candidate.name === state.agent!.name) : undefined;
	if (agent || !state.agent || !existsSync(systemPromptPath)) {
		await writeFile(systemPromptPath, buildSystemPrompt(state, agent), { mode: 0o600 });
	}

	const scriptPath = join(run, followUp ? "resume.sh" : "launch.sh");
	const invocation = state.child.pi ?? getPiInvocation();
	const args = [
		invocation.command,
		...invocation.args,
		"--session-id",
		state.child.sessionId,
		"--name",
		`subagent:${state.name}`,
		"-e",
		childExtensionPath,
		state.child.systemPromptMode === "replace" ? "--system-prompt" : "--append-system-prompt",
		systemPromptPath,
	];
	if (state.child.tools) args.push("--tools", state.child.tools.join(","));
	if (state.child.model) args.push("--model", state.child.model);
	if (state.child.thinkingLevel) args.push("--thinking", state.child.thinkingLevel);
	args.push("--", `@${promptPath}`);

	await writeFile(
		scriptPath,
		[
			"#!/usr/bin/env bash",
			"set -euo pipefail",
			"# Keep this pane after Pi exits so a crash stays inspectable and the parent",
			"# can read the exit status. Done here, before exec, so a fast exit cannot race it.",
			'if [ -n "${TMUX_PANE:-}" ]; then tmux set-option -w -t "$TMUX_PANE" remain-on-exit on || true; fi',
			`export PI_SUBAGENT_ID=${shellQuote(state.id)}`,
			`export PI_SUBAGENT_RUN_DIR=${shellQuote(run)}`,
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
	if (!windowId) throw new Error("tmux did not return a window id");
	return { windowId };
}

function buildInitialPrompt(state: SubagentState): string {
	return ["Your assignment:", "", state.task, ""].join("\n");
}

function buildSystemPrompt(state: SubagentState, agent?: AgentDefinition): string {
	const persona = agent?.systemPrompt?.trim();
	return [persona ? `${persona}\n` : undefined, buildContract(state)].filter(Boolean).join("\n");
}

function buildContract(state: SubagentState): string {
	return [
		"# Subagent contract",
		"",
		"You are a Pi subagent running in an interactive tmux window, started by a parent Pi session. The human can watch and type here at any time.",
		"",
		"Your assignment arrives as the first user message. It is bounded: complete only that assignment and report explicitly when it is done, blocked, or failed.",
		"",
		"- Use `subagent_report` exactly once for the terminal outcome: `done`, `failed`, or `needs-human`. Being idle is not completion.",
		"- Use `subagent_ask` for a decision you cannot make yourself. Your turn ends after asking; the answer arrives as the next user message, typed by the human here or relayed by the parent. Never guess an answer and continue.",
		"- Do not merge, push, delete, clean, or retire your worktree or session.",
		"- Do not commit unless the assignment explicitly asks you to.",
		state.git?.worktreePath
			? `- You are working in an isolated Git worktree at ${state.git.worktreePath}, branch ${state.git.branch}, based on ${state.git.baseCommit}.`
			: `- You are running in the parent checkout at ${state.child.cwd}${state.child.tools ? " with a read-only tool set" : ""}; do not mutate files unless the assignment explicitly asks.`,
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

async function resolveSubagent(ref: string): Promise<SubagentState> {
	const states = await listStates();
	const matches = matchSubagents(states, ref);
	if (matches.length === 1) return matches[0];
	const known = states.length === 0 ? "none" : states.map((state) => `${state.name} (${shortId(state.id)}, ${state.status})`).join(", ");
	if (matches.length === 0) throw new Error(`No subagent matched "${ref}". Known subagents: ${known}.`);
	const ambiguous = matches.map((state) => `${state.name} (${state.id})`).join(", ");
	throw new Error(`"${ref}" is ambiguous; it matches ${ambiguous}. Use the full id.`);
}

async function readQuestions(state: SubagentState): Promise<ChildQuestion[]> {
	const dir = questionsDir(runDir(state.id));
	if (!existsSync(dir)) return [];
	const questions: ChildQuestion[] = [];
	for (const file of (await readdir(dir)).sort()) {
		if (!file.endsWith(".json")) continue;
		const question = await readJson<ChildQuestion>(join(dir, file)).catch(() => undefined);
		if (question) questions.push(question);
	}
	return questions;
}

function formatAgentSummary(agent: AgentDefinition): string {
	return [
		`${agent.name}: ${agent.description}`,
		`  tools: ${agent.tools === undefined ? "Pi default" : agent.tools.length === 0 ? "none" : agent.tools.join(", ")} (plus ${CHILD_TOOLS.join(", ")})`,
		`  model: ${agent.model ?? "inherit"}${agent.thinking ? ` thinking: ${agent.thinking}` : ""}`,
		`  mode: ${agent.mode ?? "worktree"} · system prompt: ${agent.systemPromptMode}`,
		`  file: ${agent.filePath}`,
	].join("\n");
}

async function formatStateSummary(state: SubagentState): Promise<string> {
	const open = openQuestions(await readQuestions(state));
	return [
		`${state.name} (${state.id})${state.agent ? ` · agent ${state.agent.name}` : ""}`,
		`status: ${state.status}${state.error ? ` — ${state.error}` : ""}`,
		`window: ${state.child.windowName}${state.child.windowId ? ` ${state.child.windowId}` : ""}`,
		`attach: tmux attach -t ${SUBAGENT_TMUX_SESSION}`,
		state.git?.worktreePath ? `worktree: ${state.git.worktreePath}` : `cwd: ${state.child.cwd}`,
		state.report ? `report: ${state.report.status} — ${state.report.summary}` : "report: none",
		state.reports?.length ? `earlier reports: ${state.reports.length}` : undefined,
		...open.map((q) => `open question ${q.id}: ${q.question}`),
		state.exit ? `exit: code ${state.exit.code ?? "unknown"} at ${state.exit.at}${state.exit.log ? ` (log: ${state.exit.log})` : ""}` : undefined,
	]
		.filter(Boolean)
		.join("\n");
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

/**
 * Deliver new questions to the parent model and keep the child's status in
 * step with whether a question is still open. Returns true when a human may
 * be needed: a question is open or the child reported needs-human.
 */
async function processQuestions(pi: ExtensionAPI, ctx: ExtensionContext, state: SubagentState, wake: (ctx: ExtensionContext, notice: Notice) => void): Promise<boolean> {
	const questions = await readQuestions(state);
	let lastQuestionAt = state.lastQuestionAt;
	for (const question of undeliveredQuestions(questions, state.lastQuestionAt)) {
		ctx.ui.notify(`Subagent ${state.name} asks: ${question.question}`, "warning");
		wake(ctx, {
			customType: "subagent-question",
			content: [
				`Subagent ${state.name} (${shortId(state.id)}) asks:`,
				question.question,
				question.context ? `Context: ${question.context}` : undefined,
				`If you can answer confidently from your own context, reply with subagent_send { id: "${shortId(state.id)}", replyTo: "${question.id}", message }. Otherwise tell the human what is being asked and stop; do not guess. The human can also answer directly in the child's tmux window, in which case a later reply is refused.`,
			]
				.filter(Boolean)
				.join("\n\n"),
			details: { subagent: state, question },
		});
		lastQuestionAt = question.createdAt;
	}

	const open = openQuestions(questions);
	const needsHuman = open.length > 0 || state.report?.status === "needs-human";
	const nextStatus = open.length > 0 ? "needs-human" : state.status === "needs-human" && !state.report ? "running" : state.status;
	if (lastQuestionAt !== state.lastQuestionAt || nextStatus !== state.status) {
		await updateState(state.id, (s) => {
			s.lastQuestionAt = lastQuestionAt;
			s.status = nextStatus;
		});
	}
	return needsHuman;
}

/** Deliver undelivered child reports. Returns true when one was delivered this pass. */
async function processReports(pi: ExtensionAPI, ctx: ExtensionContext, state: SubagentState, wake: (ctx: ExtensionContext, notice: Notice) => void): Promise<boolean> {
	const dir = reportsDir(runDir(state.id));
	if (!existsSync(dir)) return false;
	let delivered = false;
	for (const file of (await readdir(dir)).sort()) {
		if (!file.endsWith(".json")) continue;
		const path = join(dir, file);
		const report = await readJson<SubagentReport>(path).catch(() => undefined);
		if (!report || report.deliveredAt) continue;
		if (!isReportDeliverable(state, report)) continue;

		const deliveredAt = nowIso();
		if (report.status === "needs-human") {
			ctx.ui.notify(`Subagent ${state.name} needs human input: ${report.summary}`, "warning");
		} else {
			wake(ctx, {
				customType: "subagent-report",
				content: [
					`Subagent ${state.name} ${report.status === "done" ? "completed" : "failed"}.`,
					`Status: ${report.status}`,
					`Summary: ${report.summary}`,
					report.artifacts.length > 0 ? `Artifacts:\n${report.artifacts.map((p) => `- ${p}`).join("\n")}` : undefined,
					state.git?.worktreePath ? `Worktree: ${state.git.worktreePath}` : undefined,
					`The child's window ${state.child.windowName} stays open for inspection.`,
				]
					.filter(Boolean)
					.join("\n\n"),
				details: { subagent: state, report },
			});
		}

		report.deliveredAt = deliveredAt;
		await writeJsonAtomic(path, report);
		await updateState(state.id, (s) => {
			s.report = report;
			s.reportDeliveredAt = deliveredAt;
			s.status = report.status;
		});
		delivered = true;
	}
	return delivered;
}

/**
 * Notice when a live child's process is gone. A child that exits without
 * reporting is marked crashed and the parent model is woken with the tail of
 * the pane so it can decide whether to resume. A child that already reported
 * needs-human and then exited is only noted, since its outcome is known.
 */
async function detectExit(pi: ExtensionAPI, ctx: ExtensionContext, state: SubagentState, wake: (ctx: ExtensionContext, notice: Notice) => void): Promise<void> {
	if (!state.child.windowId) return;
	const window = await inspectWindow(pi, state.child.windowId);
	if (window.exists && !window.dead) return;

	const run = runDir(state.id);
	const at = nowIso();
	let log: string | undefined;
	let excerpt = "";
	if (window.exists) {
		const captured = await pi.exec("tmux", ["capture-pane", "-p", "-J", "-t", state.child.windowId, "-S", `-${crashLogLines}`], { timeout: 2000 }).catch(() => undefined);
		if (captured && captured.code === 0 && captured.stdout.trim()) {
			log = crashLogPath(run);
			await writeFile(log, captured.stdout, { mode: 0o600 }).catch(() => undefined);
			excerpt = tailLines(captured.stdout, crashReportLines);
		}
	}
	const info = await readJson<ChildInfo>(childInfoPath(run)).catch(() => undefined);
	const where = window.exists ? `exited with code ${window.exitCode ?? "unknown"}` : "tmux window is gone";

	if (state.report) {
		// Outcome already known (needs-human); just record that the process is gone.
		await updateState(state.id, (s) => {
			s.exit = { code: window.exitCode, at, log };
		});
		ctx.ui.notify(`Subagent ${state.name} ${where} while waiting for human input. Resume it with subagent_resume.`, "warning");
		return;
	}

	await updateState(state.id, (s) => {
		s.status = "crashed";
		s.exit = { code: window.exitCode, at, log };
	});
	wake(ctx, {
		customType: "subagent-crash",
		content: [
			`Subagent ${state.name} ${where} without reporting an outcome.`,
			`Status: crashed`,
			log ? `Pane output saved to: ${log}` : undefined,
			info?.sessionFile ? `Child session: ${info.sessionFile}` : undefined,
			state.git?.worktreePath ? `Worktree: ${state.git.worktreePath}` : undefined,
			excerpt ? `Last output:\n\`\`\`\n${excerpt}\n\`\`\`` : undefined,
			"Use subagent_resume to reopen the child in the same session, or subagent_status for details.",
		]
			.filter(Boolean)
			.join("\n\n"),
		details: { subagent: state, exit: { code: window.exitCode, at, log } },
	});
}

/**
 * Point tmux-attention at the parent pane while a child waits on a human and
 * the parent model has nothing to do, so `jump` lands here rather than in the
 * subagents session, which it skips. Cleared to idle once nothing is pending.
 */
let parentPaneBlocked = false;
async function updateParentAttention(pi: ExtensionAPI, ctx: ExtensionContext, humanNeeded: boolean): Promise<void> {
	if (humanNeeded && ctx.isIdle() && !parentPaneBlocked) {
		parentPaneBlocked = true;
		setTimeout(() => void tmuxAttention(pi, "blocked"), parentAttentionDelayMs);
	} else if (!humanNeeded && parentPaneBlocked) {
		parentPaneBlocked = false;
		if (ctx.isIdle()) await tmuxAttention(pi, "idle");
	}
}

async function hasTmuxSession(pi: ExtensionAPI): Promise<boolean> {
	const result = await pi.exec("tmux", ["has-session", "-t", SUBAGENT_TMUX_SESSION], { timeout: 1000 }).catch(() => ({ code: 1 }));
	return result.code === 0;
}

/** Window ids are unique per tmux server, so target the window directly. */
async function inspectWindow(pi: ExtensionAPI, windowId: string): Promise<WindowInspection> {
	const result = await pi
		.exec("tmux", ["list-panes", "-t", windowId, "-F", "#{pane_dead} #{pane_dead_status}"], { timeout: 1000 })
		.catch(() => ({ code: 1, stdout: "" }));
	if (result.code !== 0) return { exists: false, dead: false };
	const panes = result.stdout.split(/\r?\n/).filter(Boolean);
	if (panes.length === 0) return { exists: false, dead: false };
	// The child runs in the window's first pane; the human may split others.
	// tmux does not interpret escapes in -F, so the fields are space separated.
	const [dead, status] = panes[0].trim().split(/\s+/);
	if (dead !== "1") return { exists: true, dead: false };
	const exitCode = status !== undefined && status !== "" ? Number(status) : undefined;
	return { exists: true, dead: true, exitCode: Number.isNaN(exitCode) ? undefined : exitCode };
}

async function closeWindow(pi: ExtensionAPI, state: SubagentState): Promise<void> {
	if (!state.child.windowId) return;
	const window = await inspectWindow(pi, state.child.windowId);
	if (!window.exists) return;
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
