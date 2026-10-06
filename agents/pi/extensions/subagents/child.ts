import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { readdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";
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

// The child never writes state.json: that file belongs to the parent. Every
// child-originated fact goes into its own file under the run directory, which
// the parent reads and annotates after handoff.
export default function (pi: ExtensionAPI) {
	const id = process.env.PI_SUBAGENT_ID;
	if (!id) return;
	const run = process.env.PI_SUBAGENT_RUN_DIR ?? runDir(id);

	let pollTimer: ReturnType<typeof setInterval> | undefined;
	let polling = false;
	let cancelled = false;
	let startedAt = nowIso();

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

	const checkCancel = (ctx: ExtensionContext) => {
		if (cancelled || !existsSync(cancelPath(run))) return;
		cancelled = true;
		if (!ctx.isIdle()) ctx.abort();
		if (pollTimer) {
			clearInterval(pollTimer);
			pollTimer = undefined;
		}
		ctx.ui.notify("The parent cancelled this subagent. Further reports will be refused; the session stays open for inspection.", "warning");
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
				pi.sendUserMessage(message.text, { deliverAs: "followUp" });
			}
		} finally {
			polling = false;
		}
	};

	pi.on("session_start", async (_event, ctx) => {
		startedAt = nowIso();
		await writeChildInfo(ctx);
		pollTimer = setInterval(() => void pollMailbox(ctx), pollIntervalMs);
		await pollMailbox(ctx);
	});

	pi.on("agent_end", async (_event, ctx) => {
		// The session file may not exist until the first message is persisted.
		await writeChildInfo(ctx);
	});

	pi.on("agent_settled", async (_event, ctx) => {
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
		label: "Ask Parent Human",
		description: "Record a mid-task question for the parent human. Use this when you need human input before continuing.",
		promptSnippet: "Ask the parent human a question when blocked on a human decision.",
		promptGuidelines: [
			"Use subagent_ask only when the subagent needs human input that it cannot decide itself.",
			"After using subagent_ask, keep the session open and wait for a mailbox reply rather than fabricating an answer.",
		],
		parameters: Type.Object({
			question: Type.String({ description: "The question for the human." }),
			context: Type.Optional(Type.String({ description: "Brief context needed to answer the question." })),
		}),
		async execute(_toolCallId, params) {
			if (cancelled) throw new Error("This subagent was cancelled by the parent; the question was not recorded.");
			const question: ChildQuestion = { id: newId(), question: params.question, context: params.context, createdAt: nowIso() };
			await writeJsonAtomic(join(questionsDir(run), eventFileName(question.createdAt, question.id)), question);
			return {
				content: [{ type: "text", text: "Question recorded for the human. Keep this session open and wait for a mailbox reply." }],
				details: { question },
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
			summary: Type.String({ description: "Concise outcome summary." }),
			artifacts: Type.Optional(Type.Array(Type.String(), { description: "Files, reports, worktree paths, or other artifacts for the parent." })),
		}),
		async execute(_toolCallId, params) {
			if (cancelled) throw new Error("This subagent was cancelled by the parent; the report was not recorded.");
			const status = params.status as ReportStatus;
			const report: SubagentReport = { id: newId(), status, summary: params.summary, artifacts: params.artifacts ?? [], createdAt: nowIso() };
			await writeJsonAtomic(join(reportsDir(run), eventFileName(report.createdAt, report.id)), report);
			return {
				content: [{ type: "text", text: status === "done" ? "Outcome recorded. The parent will close this window after it accepts delivery." : "Outcome recorded. Keep this window open for inspection." }],
				details: { report },
				terminate: true,
			};
		},
	});
}
