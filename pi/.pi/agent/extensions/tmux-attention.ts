import { uuidv7 } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { join } from "node:path";

const attentionPath = join(process.env.HOME ?? "", ".local/bin/tmux-attention");
const summaryIntervalMs = 45_000;
const summaryDebounceMs = 5_000;
const maxConversationChars = 8_000;
const paneTitlePrefix = "π ";

export default function (pi: ExtensionAPI) {
	const inTmux = () => Boolean(process.env.TMUX);
	const paneTarget = () => process.env.TMUX_PANE;

	const attention = async (state: "working" | "blocked" | "done" | "clear") => {
		if (!inTmux()) {
			return;
		}

		try {
			await pi.exec("tmux-attention", [state], { timeout: 1000 });
		} catch {
			if (existsSync(attentionPath)) {
				await pi.exec(attentionPath, [state], { timeout: 1000 }).catch(() => undefined);
			}
		}
	};

	const tmux = async (...args: string[]) => {
		if (!inTmux()) {
			return;
		}

		await pi.exec("tmux", args, { timeout: 1000 }).catch(() => undefined);
	};

	const setPaneTitle = async (title: string) => {
		const target = paneTarget();
		if (!target) {
			return;
		}

		await tmux("select-pane", "-t", target, "-T", title);
	};

	const textFromContent = (content: unknown): string => {
		if (typeof content === "string") {
			return content;
		}

		if (!Array.isArray(content)) {
			return "";
		}

		return content
			.map((part) => {
				if (!part || typeof part !== "object") {
					return "";
				}

				const block = part as { type?: string; text?: string; name?: string; arguments?: unknown };
				if (block.type === "text" && typeof block.text === "string") {
					return block.text;
				}
				if (block.type === "toolCall" && typeof block.name === "string") {
					return `Tool: ${block.name}`;
				}
				return "";
			})
			.filter(Boolean)
			.join("\n");
	};

	const conversationText = (ctx: ExtensionContext): string => {
		const entries = ctx.sessionManager.getBranch() as Array<{
			type?: string;
			message?: { role?: string; content?: unknown };
		}>;
		const sections: string[] = [];

		for (const entry of entries) {
			const role = entry.message?.role;
			if (entry.type !== "message" || (role !== "user" && role !== "assistant")) {
				continue;
			}

			const text = textFromContent(entry.message.content).trim();
			if (text) {
				sections.push(`${role}: ${text}`);
			}
		}

		return sections.join("\n\n").slice(-maxConversationChars);
	};

	const summarizeTitle = async (ctx: ExtensionContext): Promise<string | undefined> => {
		const conversation = conversationText(ctx).trim();
		if (!conversation) {
			return undefined;
		}

		const response = await ctx.modelRegistry.complete(
			ctx.model,
			{
				messages: [
					{
						role: "user" as const,
						content: [
							{
								type: "text" as const,
								text: [
									"Create a terse tmux pane title for this pi coding-agent conversation.",
									"Return only the title: 2-6 words, no quotes, no punctuation unless needed.",
									"Focus on the user's current task and recent progress.",
									"",
									"<conversation>",
									conversation,
									"</conversation>",
								].join("\n"),
							},
						],
						timestamp: Date.now(),
					},
				],
			},
			{
				reasoningEffort: "low",
				cacheRetention: "none",
				sessionId: uuidv7(),
			},
		);

		const title = response.content
			.filter((part): part is { type: "text"; text: string } => part.type === "text")
			.map((part) => part.text)
			.join(" ")
			.replace(/[\r\n]+/g, " ")
			.replace(/^['\"]|['\"]$/g, "")
			.trim();

		return title ? title.slice(0, 80) : undefined;
	};

	let summaryTimer: ReturnType<typeof setTimeout> | undefined;
	let summaryInterval: ReturnType<typeof setInterval> | undefined;
	let summaryInFlight = false;
	let titleDirty = true;
	let lastTitle = "";

	const refreshTitle = async (ctx: ExtensionContext) => {
		if (!inTmux() || summaryInFlight || !titleDirty) {
			return;
		}

		summaryInFlight = true;
		try {
			const title = await summarizeTitle(ctx);
			const paneTitle = title ? `${paneTitlePrefix}${title}` : undefined;
			if (paneTitle && paneTitle !== lastTitle) {
				lastTitle = paneTitle;
				await setPaneTitle(paneTitle);
			}
			titleDirty = false;
		} catch {
			// Keep the previous title if title summarization fails.
		} finally {
			summaryInFlight = false;
		}
	};

	const scheduleTitleRefresh = (ctx: ExtensionContext, delay = summaryDebounceMs) => {
		titleDirty = true;
		if (summaryTimer) {
			return;
		}

		summaryTimer = setTimeout(() => {
			summaryTimer = undefined;
			void refreshTitle(ctx);
		}, delay);
	};

	pi.on("session_start", async (_event, ctx) => {
		scheduleTitleRefresh(ctx, 500);
		summaryInterval = setInterval(() => {
			if (!ctx.isIdle()) {
				scheduleTitleRefresh(ctx);
			}
		}, summaryIntervalMs);
	});

	pi.on("before_agent_start", async (_event, ctx) => {
		scheduleTitleRefresh(ctx, 1_000);
		await attention("working");
	});

	pi.on("ui_prompt_start", async () => {
		await attention("blocked");
	});

	pi.on("ui_prompt_end", async (_event, ctx) => {
		await attention(ctx.isIdle() ? "clear" : "working");
	});

	pi.on("agent_settled", async (_event, ctx) => {
		scheduleTitleRefresh(ctx, 1_000);
		await attention("done");
	});

	pi.on("session_shutdown", async () => {
		if (summaryTimer) {
			clearTimeout(summaryTimer);
			summaryTimer = undefined;
		}
		if (summaryInterval) {
			clearInterval(summaryInterval);
			summaryInterval = undefined;
		}
		await setPaneTitle("");
		await attention("clear");
	});
}
