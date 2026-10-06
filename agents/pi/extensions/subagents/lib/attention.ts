import { existsSync } from "node:fs";
import { join } from "node:path";

export type AttentionState = "working" | "blocked" | "failed" | "done" | "idle" | "clear";

type Exec = { exec(command: string, args: string[], options?: { timeout?: number }): Promise<{ code: number }> };

const shimPath = join(process.env.HOME ?? "", ".local/share/mise/shims/tmux-attention");

/**
 * Mark a tmux pane for the tmux-attention picker. Silent outside tmux and when
 * the CLI is missing, matching the standalone tmux-attention extension. The
 * pane defaults to the calling process's own pane.
 */
export async function tmuxAttention(pi: Exec, state: AttentionState, paneId?: string): Promise<void> {
	if (!process.env.TMUX) return;
	const args = paneId ? [state, paneId] : [state];
	try {
		const result = await pi.exec("tmux-attention", args, { timeout: 1000 });
		if (result.code === 0) return;
	} catch {
		// fall through to the shim path
	}
	if (existsSync(shimPath)) {
		await pi.exec(shimPath, args, { timeout: 1000 }).catch(() => undefined);
	}
}

/** The pane id of a tmux window's first pane, for marking a child from the parent. */
export async function windowPaneId(pi: { exec(command: string, args: string[], options?: { timeout?: number }): Promise<{ code: number; stdout: string }> }, windowId: string): Promise<string | undefined> {
	const result = await pi.exec("tmux", ["list-panes", "-t", windowId, "-F", "#{pane_id}"], { timeout: 1000 }).catch(() => undefined);
	if (!result || result.code !== 0) return undefined;
	return result.stdout.split(/\r?\n/).find(Boolean);
}
