import { createHash, randomUUID } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

export const SUBAGENT_TMUX_SESSION = "pi-subagents";
export const STATE_VERSION = 2;

export type SubagentStatus =
	| "starting"
	| "running"
	| "needs-human"
	| "done"
	| "failed"
	| "cancelled"
	| "crashed";

export type ReportStatus = "done" | "failed" | "needs-human";

export type SubagentMode = "worktree" | "shared-read";

/**
 * Parent-owned state. Only the parent extension writes `state.json`; the child
 * communicates through its own files (reports/, questions/, child.json) that
 * the parent reads and, after handoff, annotates.
 */
export type SubagentState = {
	version: number;
	id: string;
	name: string;
	task: string;
	summary?: string;
	mode: SubagentMode;
	status: SubagentStatus;
	createdAt: string;
	updatedAt: string;
	parent: {
		cwd: string;
		sessionFile?: string;
		sessionId?: string;
	};
	git?: {
		repoRoot: string;
		repoHash: string;
		baseCommit: string;
		parentDirty: boolean;
		branch?: string;
		worktreePath?: string;
	};
	child: {
		sessionId: string;
		cwd: string;
		windowName: string;
		windowId?: string;
		model?: string;
		thinkingLevel?: string;
		/** Exact Pi invocation captured at start so resume launches the same binary. */
		pi?: { command: string; args: string[] };
	};
	/** Most recent delivered report for the current run of the child. */
	report?: SubagentReport;
	reportDeliveredAt?: string;
	/** Reports from earlier runs, archived on resume. */
	reports?: SubagentReport[];
	lastQuestionAt?: string;
	cancelledAt?: string;
	/** Set when the child process exited without being told to. */
	exit?: { code?: number; at: string; log?: string };
	/** Launch or runtime error recorded by the parent. */
	error?: string;
};

export type SubagentReport = {
	id: string;
	status: ReportStatus;
	summary: string;
	artifacts: string[];
	createdAt: string;
	/** Written by the parent once the report has been delivered. */
	deliveredAt?: string;
};

export type MailboxMessage = {
	id: string;
	text: string;
	createdAt: string;
	status: "queued" | "accepted";
	acceptedAt?: string;
};

export type ChildQuestion = {
	id: string;
	question: string;
	context?: string;
	createdAt: string;
	/** Written by the parent once the human has been notified. */
	notifiedAt?: string;
};

/** Written by the child so the parent can find its session and process. */
export type ChildInfo = {
	pid: number;
	cwd: string;
	sessionFile?: string;
	startedAt: string;
	updatedAt: string;
};

export type CancelMarker = {
	createdAt: string;
	reason?: string;
};

export function nowIso(): string {
	return new Date().toISOString();
}

export function newId(): string {
	return randomUUID();
}

export function shortId(id: string): string {
	return id.replace(/-/g, "").slice(0, 8);
}

export function slugify(input: string, fallback = "task"): string {
	const slug = input
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+|-+$/g, "")
		.slice(0, 40);
	return slug || fallback;
}

export function formatTaskSummary(task: string, summary?: string): string {
	const text = (summary?.trim() || task).replace(/\s+/g, " ").trim();
	const characters = Array.from(text);
	return characters.length > 240 ? `${characters.slice(0, 239).join("")}…` : text;
}

export function repoHash(repoRoot: string): string {
	return createHash("sha256").update(repoRoot).digest("hex").slice(0, 16);
}

export function agentRoot(): string {
	return join(process.env.HOME ?? ".", ".pi", "agent", "subagents");
}

export function runDir(id: string): string {
	return join(agentRoot(), "runs", id);
}

export function statePath(id: string): string {
	return join(runDir(id), "state.json");
}

// Run-directory layout. These take the run directory rather than the id so the
// child can resolve them from PI_SUBAGENT_RUN_DIR without depending on HOME.

export function mailboxDir(run: string): string {
	return join(run, "mailbox");
}

export function questionsDir(run: string): string {
	return join(run, "questions");
}

export function reportsDir(run: string): string {
	return join(run, "reports");
}

export function childInfoPath(run: string): string {
	return join(run, "child.json");
}

export function cancelPath(run: string): string {
	return join(run, "cancel.json");
}

export function crashLogPath(run: string): string {
	return join(run, "crash.log");
}

export function worktreePath(hash: string, id: string): string {
	return join(agentRoot(), "worktrees", hash, id);
}

/** Sortable file name for append-only per-event files. */
export function eventFileName(createdAt: string, id: string): string {
	return `${createdAt.replace(/[:.]/g, "-")}-${id}.json`;
}

export async function ensureDir(path: string): Promise<void> {
	await mkdir(path, { recursive: true, mode: 0o700 });
}

export async function writeJsonAtomic(path: string, value: unknown): Promise<void> {
	await ensureDir(dirname(path));
	const tmp = `${path}.${process.pid}.${Date.now()}.tmp`;
	await writeFile(tmp, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
	await rename(tmp, path);
}

export async function readJson<T>(path: string): Promise<T> {
	return JSON.parse(await readFile(path, "utf8")) as T;
}

/** Parent-only. The child must never call this; see SubagentState. */
export async function updateState(id: string, updater: (state: SubagentState) => SubagentState | void): Promise<SubagentState> {
	const current = await readJson<SubagentState>(statePath(id));
	const updated = updater(current);
	const next = updated ?? current;
	next.updatedAt = nowIso();
	await writeJsonAtomic(statePath(id), next);
	return next;
}

export function shellQuote(value: string): string {
	return `'${value.replace(/'/g, `'"'"'`)}'`;
}

export function modelPattern(model?: { provider?: string; id?: string } | null): string | undefined {
	if (!model?.id) return undefined;
	return model.provider ? `${model.provider}/${model.id}` : model.id;
}

const terminalStatuses: ReadonlySet<SubagentStatus> = new Set(["done", "failed", "cancelled", "crashed"]);

/** Terminal children are not scanned for reports, questions, or crashes until resumed. */
export function isTerminalStatus(status: SubagentStatus): boolean {
	return terminalStatuses.has(status);
}

/**
 * Match a user- or model-supplied reference against known children. Accepts an
 * exact id, an exact name, or an id prefix (with or without dashes), in that
 * order of preference so a short prefix that is also a full name is unambiguous.
 */
export function matchSubagents(states: SubagentState[], ref: string): SubagentState[] {
	const needle = ref.trim();
	if (!needle) return [];
	const exactId = states.filter((state) => state.id === needle);
	if (exactId.length > 0) return exactId;
	const exactName = states.filter((state) => state.name === needle);
	if (exactName.length > 0) return exactName;
	const compact = needle.replace(/-/g, "").toLowerCase();
	return states.filter((state) => state.id.replace(/-/g, "").toLowerCase().startsWith(compact));
}

/**
 * Children worth showing by default: anything still live from any parent
 * session (a restarted parent must still see them), plus finished children
 * that belong to the current parent session.
 */
export function visibleStates(states: SubagentState[], currentSessionId?: string): SubagentState[] {
	return states.filter((state) => !isTerminalStatus(state.status) || (currentSessionId !== undefined && state.parent.sessionId === currentSessionId));
}

/**
 * A report is delivered unless the parent cancelled the child before the
 * report was written. Reports from before the cancellation still count.
 */
export function isReportDeliverable(state: Pick<SubagentState, "cancelledAt">, report: Pick<SubagentReport, "createdAt">): boolean {
	return !state.cancelledAt || report.createdAt < state.cancelledAt;
}

/** Last `limit` non-empty lines of captured pane output, for crash reports. */
export function tailLines(text: string, limit: number): string {
	const lines = text.split(/\r?\n/).map((line) => line.trimEnd());
	while (lines.length > 0 && lines[lines.length - 1] === "") lines.pop();
	return lines.slice(-limit).join("\n");
}
