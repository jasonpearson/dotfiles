import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { readdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";
import {
	mailboxDir,
	newId,
	nowIso,
	questionsDir,
	readJson,
	updateState,
	writeJsonAtomic,
	type ChildQuestion,
	type MailboxMessage,
	type ReportStatus,
} from "./lib/common";

const pollIntervalMs = 2_000;

export default function (pi: ExtensionAPI) {
	const id = process.env.PI_SUBAGENT_ID;
	if (!id) return;

	let pollTimer: ReturnType<typeof setInterval> | undefined;
	let polling = false;

	const pollMailbox = async (ctx: ExtensionContext) => {
		if (polling || !ctx.isIdle()) return;
		polling = true;
		try {
			const dir = mailboxDir(id);
			if (!existsSync(dir)) return;
			const files = (await readdir(dir)).filter((file) => file.endsWith(".json")).sort();
			for (const file of files) {
				if (!ctx.isIdle()) return;
				const path = join(dir, file);
				const message = await readJson<MailboxMessage>(path).catch(() => undefined);
				if (!message || message.status !== "queued") continue;
				try {
					await pi.sendUserMessage(message.text);
					message.status = "accepted";
					message.acceptedAt = nowIso();
				} catch (error) {
					message.status = "failed";
					message.failedAt = nowIso();
					message.error = error instanceof Error ? error.message : String(error);
				}
				await writeJsonAtomic(path, message);
			}
		} finally {
			polling = false;
		}
	};

	pi.on("session_start", async (_event, ctx) => {
		pollTimer = setInterval(() => void pollMailbox(ctx), pollIntervalMs);
		await pollMailbox(ctx);
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
			const question: ChildQuestion = { id: newId(), question: params.question, context: params.context, createdAt: nowIso() };
			await writeJsonAtomic(join(questionsDir(id), `${question.createdAt.replace(/[:.]/g, "-")}-${question.id}.json`), question);
			await updateState(id, (state) => {
				state.status = "needs-human";
				state.lastQuestionAt = question.createdAt;
			});
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
			const status = params.status as ReportStatus;
			const report = { status, summary: params.summary, artifacts: params.artifacts ?? [], createdAt: nowIso() };
			await updateState(id, (state) => {
				state.status = status;
				state.report = report;
			});
			return {
				content: [{ type: "text", text: status === "done" ? "Outcome recorded. The parent will close this window after it accepts delivery." : "Outcome recorded. Keep this window open for inspection." }],
				details: { report },
				terminate: true,
			};
		},
	});
}
