import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { join } from "node:path";

const attentionPath = join(process.env.HOME ?? "", ".tmux/plugins/tmux-attention/bin/tmux-attention");

export default function (pi: ExtensionAPI) {
	const inTmux = () => Boolean(process.env.TMUX);

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

	pi.on("session_start", async () => {
		await tmux("rename-window", "pi");
	});

	pi.on("before_agent_start", async () => {
		await attention("working");
	});

	pi.on("ui_prompt_start", async () => {
		await attention("blocked");
	});

	pi.on("ui_prompt_end", async (_event, ctx) => {
		await attention(ctx.isIdle() ? "clear" : "working");
	});

	pi.on("agent_settled", async () => {
		await attention("done");
	});

	pi.on("session_shutdown", async () => {
		await attention("clear");
		await tmux("set-window-option", "automatic-rename", "on");
	});
}
