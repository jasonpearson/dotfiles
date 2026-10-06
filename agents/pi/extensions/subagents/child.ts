import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { readdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { tmuxAttention, type AttentionState } from "./lib/attention";
import {
	cancelPath,
	childInfoPath,
	eventFileName,
	mailboxDir,
	newId,
	nowIso,
	questionsDir,
	readJson,
	reportsDir,
	runDir,
	writeJsonAtomic,
	type ChildInfo,
	type ChildQuestion,
	type MailboxMessage,
	type ReportStatus,
	type SubagentReport,
} from "./lib/common";

const pollIntervalMs = 2_000;
// The global tmux-attention extension marks this pane "done" when the agent
// settles. Re-assert our more specific state shortly after so it wins.
const attentionReassertMs = 300;

// The child never writes state.json: that file belongs to the parent. Every
// child-originated fact goes into its own file under the run directory, which
// the parent reads. Question files are child-owned end to end: the child
// creates them and marks them answered.
export default function (pi: ExtensionAPI) {
	const id = process.env.PI_SUBAGENT_ID;
	if (!id) return;
	const run = process.env.PI_SUBAGENT_RUN_DIR ?? runDir(id);

	let pollTimer: ReturnType<typeof setInterval> | undefined;
	let polling = false;
	let cancelled = false;
	let startedAt = nowIso();
	let lastReportStatus: ReportStatus | undefined;
	const openQuestions = new Map<string, string>(); // question id -> file path

	const attention = (state: AttentionState) => tmuxAttention(pi, state);

	const reassertAttention = (state: AttentionState) => {
		setTimeout(() => void attention(state), attentionReassertMs);
	};

	const writeChildInfo = async (ctx: ExtensionContext) => {
		const info: ChildInfo = {
			pid: process.pid,
			cwd: ctx.cwd,
			sessionFile: ctx.sessionManager.getSessionFile(),
			startedAt,
			updatedAt: nowIso(),
		};
		await writeJsonAtomic(childInfoPath(run), info).catch(() => undefined);
	};

	const loadOpenQuestions = async () => {
		const dir = questionsDir(run);
		if (!existsSync(dir)) return;
		for (const file of await readdir(dir)) {
			if (!file.endsWith(".json")) continue;
			const path = join(dir, file);
			const question = await readJson<ChildQuestion>(path).catch(() => undefined);
			if (question && !question.answeredAt) openQuestions.set(question.id, path);
		}
	};

	const markAnswered = async (questionId: string, by: ChildQuestion["answeredBy"]) => {
		const path = openQuestions.get(questionId);
		openQuestions.delete(questionId);
		if (!path) return;
		const question = await readJson<ChildQuestion>(path).catch(() => undefined);
		if (!question || question.answeredAt) return;
		question.answeredAt = nowIso();
		question.answeredBy = by;
		await writeJsonAtomic(path, question).catch(() => undefined);
	};

	const checkCancel = (ctx: ExtensionContext) => {
		if (cancelled || !existsSync(cancelPath(run))) return;
		cancelled = true;
		if (!ctx.isIdle()) ctx.abort();
		if (pollTimer) {
			clearInterval(pollTimer);
			pollTimer = undefined;
		}
		ctx.ui.notify("The parent cancelled this subagent. Further reports will be refused; the session stays open for inspection.", "warning");
		void attention("idle");
	};

	const pollMailbox = async (ctx: ExtensionContext) => {
		if (polling) return;
		polling = true;
		try {
			checkCancel(ctx);
			if (cancelled || !ctx.isIdle()) return;
			const dir = mailboxDir(run);
			if (!existsSync(dir)) return;
			const files = (await readdir(dir)).filter((file) => file.endsWith(".json")).sort();
			for (const file of files) {
				if (!ctx.isIdle()) return;
				const path = join(dir, file);
				const message = await readJson<MailboxMessage>(path).catch(() => undefined);
				if (!message || message.status !== "queued") continue;
				// Mark accepted before injecting so a crash mid-send cannot replay it.
				message.status = "accepted";
				message.acceptedAt = nowIso();
				await writeJsonAtomic(path, message);
				if (message.replyTo) await markAnswered(message.replyTo, "parent");
				pi.sendUserMessage(message.text, { deliverAs: "followUp" });
			}
		} finally {
			polling = false;
		}
	};

	pi.on("session_start", async (_event, ctx) => {
		startedAt = nowIso();
		await writeChildInfo(ctx);
		await loadOpenQuestions();
		pollTimer = setInterval(() => void pollMailbox(ctx), pollIntervalMs);
		await pollMailbox(ctx);
	});

	pi.on("agent_start", async () => {
		// A turn started while a question was open and no mailbox reply claimed
		// it: the human answered by typing in this window.
		for (const questionId of [...openQuestions.keys()]) {
			await markAnswered(questionId, "window");
		}
	});

	pi.on("agent_end", async (_event, ctx) => {
		// The session file may not exist until the first message is persisted.
		await writeChildInfo(ctx);
	});

	pi.on("agent_settled", async (_event, ctx) => {
		if (openQuestions.size > 0) reassertAttention("blocked");
		else if (lastReportStatus === "failed") reassertAttention("failed");
		else if (lastReportStatus === "needs-human") reassertAttention("blocked");
		lastReportStatus = undefined;
		await pollMailbox(ctx);
	});

	pi.on("session_shutdown", async () => {
		if (pollTimer) {
			clearInterval(pollTimer);
			pollTimer = undefined;
		}
	});

	pi.registerTool({
		name: "subagent_ask",
		label: "Ask Parent",
		description:
			"Ask the parent a question you cannot decide yourself. Your turn ends after asking; the answer arrives as the next user message, either typed by the human in this window or relayed by the parent agent.",
		promptSnippet: "Ask the parent a question when blocked on a decision you cannot make yourself.",
		promptGuidelines: [
			"Use subagent_ask only for decisions the assignment does not settle and you cannot verify yourself.",
			"After subagent_ask your turn ends. Do not guess an answer and continue; wait for the next user message.",
			"Ask one clear question with the context needed to answer it in a sentence or two.",
		],
		parameters: Type.Object({
			question: Type.String({ description: "The question, phrased so it can be answered briefly." }),
			context: Type.Optional(Type.String({ description: "Brief context needed to answer the question." })),
		}),
		async execute(_toolCallId, params) {
			if (cancelled) throw new Error("This subagent was cancelled by the parent; the question was not recorded.");
			const question: ChildQuestion = { id: newId(), question: params.question, context: params.context, createdAt: nowIso() };
			const path = join(questionsDir(run), eventFileName(question.createdAt, question.id));
			await writeJsonAtomic(path, question);
			openQuestions.set(question.id, path);
			await attention("blocked");
			return {
				content: [{ type: "text", text: "Question recorded. Your turn ends now; the answer will arrive as the next user message." }],
				details: { question },
				terminate: true,
			};
		},
	});

	pi.registerTool({
		name: "subagent_report",
		label: "Report Subagent Outcome",
		description: "Submit the terminal outcome for this delegated assignment. Required: idle is not completion.",
		promptSnippet: "Report the subagent's terminal outcome when the bounded assignment is done, failed, or needs human action.",
		promptGuidelines: [
			"Use subagent_report exactly once when the subagent assignment has a terminal outcome.",
			"Use status `done` only when the assigned task is complete and validated as far as practical.",
			"Use status `failed` when the task was attempted but cannot be completed.",
			"Use status `needs-human` when final completion depends on a human decision or action.",
		],
		parameters: Type.Object({
			status: StringEnum(["done", "failed", "needs-human"] as const),
			summary: Type.String({ description: "Concise outcome summary in the format your agent definition asks for." }),
			artifacts: Type.Optional(Type.Array(Type.String(), { description: "Files, reports, worktree paths, or other artifacts for the parent." })),
		}),
		async execute(_toolCallId, params) {
			if (cancelled) throw new Error("This subagent was cancelled by the parent; the report was not recorded.");
			const status = params.status as ReportStatus;
			const report: SubagentReport = { id: newId(), status, summary: params.summary, artifacts: params.artifacts ?? [], createdAt: nowIso() };
			await writeJsonAtomic(join(reportsDir(run), eventFileName(report.createdAt, report.id)), report);
			lastReportStatus = status;
			await attention(status === "done" ? "done" : status === "failed" ? "failed" : "blocked");
			return {
				content: [{ type: "text", text: "Outcome recorded. This window stays open for inspection until the parent retires it." }],
				details: { report },
				terminate: true,
			};
		},
	});
}
