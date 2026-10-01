import { createHash, randomUUID } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

export const SUBAGENT_TMUX_SESSION = "pi-subagents";
export const STATE_VERSION = 1;

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
	};
	report?: SubagentReport;
	reportDeliveredAt?: string;
	lastQuestionAt?: string;
	cancelledAt?: string;
};

export type SubagentReport = {
	status: ReportStatus;
	summary: string;
	artifacts: string[];
	createdAt: string;
};

export type MailboxMessage = {
	id: string;
	text: string;
	createdAt: string;
	status: "queued" | "accepted" | "failed";
	acceptedAt?: string;
	failedAt?: string;
	error?: string;
};

export type ChildQuestion = {
	id: string;
	question: string;
	context?: string;
	createdAt: string;
	notifiedAt?: string;
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

export function mailboxDir(id: string): string {
	return join(runDir(id), "mailbox");
}

export function questionsDir(id: string): string {
	return join(runDir(id), "questions");
}

export function worktreePath(hash: string, id: string): string {
	return join(agentRoot(), "worktrees", hash, id);
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
