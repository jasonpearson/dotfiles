import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join } from "node:path";
import type { SubagentMode, SystemPromptMode } from "./common";

/** Tools every child must keep so it can ask and report. */
export const CHILD_TOOLS = ["subagent_ask", "subagent_report"] as const;

/** Enforced tool set for shared-read children started without an agent. */
export const READ_ONLY_TOOLS = ["read", "grep", "find", "ls"] as const;

export const AGENT_FILE_NAME = "AGENT.md";

export type AgentDefinition = {
	name: string;
	description: string;
	/** undefined: Pi's default tools. []: no tools beyond the child tools. */
	tools?: string[];
	model?: string;
	thinking?: string;
	mode?: SubagentMode;
	systemPromptMode: SystemPromptMode;
	systemPrompt: string;
	filePath: string;
};

export type AgentDiscovery = { agents: AgentDefinition[]; errors: string[] };

export function agentsDir(): string {
	return join(process.env.HOME ?? ".", ".pi", "agent", "agents");
}

type FrontmatterValue = string | string[];

/**
 * Minimal frontmatter reader: `key: value` scalars, `key: a, b` lists, and
 * block lists of `- item` lines. Deliberately not YAML so agent files stay
 * testable without Pi's package and so an odd file cannot throw.
 */
export function parseFrontmatter(content: string): { frontmatter: Record<string, FrontmatterValue>; body: string } {
	const lines = content.split(/\r?\n/);
	if (lines[0]?.trim() !== "---") return { frontmatter: {}, body: content };
	const end = lines.findIndex((line, index) => index > 0 && line.trim() === "---");
	if (end === -1) return { frontmatter: {}, body: content };

	const frontmatter: Record<string, FrontmatterValue> = {};
	let currentKey: string | undefined;
	for (const raw of lines.slice(1, end)) {
		const line = raw.replace(/\s+#.*$/, "");
		if (!line.trim() || line.trim().startsWith("#")) continue;
		const item = /^\s+-\s*(.*)$/.exec(line);
		if (item && currentKey) {
			const existing = frontmatter[currentKey];
			const list = Array.isArray(existing) ? existing : existing ? [existing] : [];
			if (item[1].trim()) list.push(unquote(item[1]));
			frontmatter[currentKey] = list;
			continue;
		}
		const pair = /^([A-Za-z_][\w-]*)\s*:\s*(.*)$/.exec(line);
		if (!pair) continue;
		currentKey = pair[1];
		frontmatter[currentKey] = unquote(pair[2]);
	}
	return { frontmatter, body: lines.slice(end + 1).join("\n").trim() };
}

function unquote(value: string): string {
	const trimmed = value.trim();
	const quoted = /^(['"])(.*)\1$/.exec(trimmed);
	return quoted ? quoted[2] : trimmed;
}

/** Comma or block list to names. A present-but-empty value yields []. */
export function parseToolList(value: FrontmatterValue | undefined): string[] | undefined {
	if (value === undefined) return undefined;
	const raw = Array.isArray(value) ? value : value.split(",");
	return raw.map((tool) => tool.trim()).filter(Boolean);
}

export function parseAgentDefinition(content: string, filePath: string): { agent?: AgentDefinition; error?: string } {
	const { frontmatter, body } = parseFrontmatter(content);
	const name = scalar(frontmatter.name);
	const description = scalar(frontmatter.description);
	if (!name || !description) return { error: `${filePath}: frontmatter needs name and description` };
	if (!/^[a-z0-9][a-z0-9_-]*$/.test(name)) return { error: `${filePath}: name "${name}" must be lowercase letters, digits, - or _` };

	let model = scalar(frontmatter.model);
	let thinking = scalar(frontmatter.thinking);
	// Accept Pi's provider/id:level form and split the level off.
	const suffix = model ? /^(.*):([a-z]+)$/.exec(model) : null;
	if (suffix && !suffix[1].includes("://")) {
		model = suffix[1];
		thinking = thinking ?? suffix[2];
	}

	const modeValue = scalar(frontmatter.mode);
	if (modeValue && modeValue !== "worktree" && modeValue !== "shared-read") return { error: `${filePath}: mode must be worktree or shared-read` };
	const promptModeValue = scalar(frontmatter.systemPromptMode) ?? "replace";
	if (promptModeValue !== "replace" && promptModeValue !== "append") return { error: `${filePath}: systemPromptMode must be replace or append` };

	return {
		agent: {
			name,
			description,
			tools: parseToolList(frontmatter.tools),
			model: model || undefined,
			thinking: thinking || undefined,
			mode: modeValue as SubagentMode | undefined,
			systemPromptMode: promptModeValue,
			systemPrompt: body,
			filePath,
		},
	};
}

function scalar(value: FrontmatterValue | undefined): string | undefined {
	if (value === undefined) return undefined;
	return Array.isArray(value) ? value.join(", ") : value;
}

/**
 * Agents live one per folder as `<dir>/<name>/AGENT.md`; a bare `<dir>/<name>.md`
 * is also accepted. Folder or file name must match the frontmatter name so
 * the symlinked layout and the registry agree.
 */
export function discoverAgents(dir: string = agentsDir()): AgentDiscovery {
	const agents = new Map<string, AgentDefinition>();
	const errors: string[] = [];
	if (!existsSync(dir)) return { agents: [], errors };

	let entries: string[];
	try {
		entries = readdirSync(dir);
	} catch (error) {
		return { agents: [], errors: [`${dir}: ${error instanceof Error ? error.message : String(error)}`] };
	}

	for (const entry of entries.sort()) {
		const path = join(dir, entry);
		let filePath: string | undefined;
		let expectedName: string | undefined;
		try {
			if (statSync(path).isDirectory()) {
				const candidate = join(path, AGENT_FILE_NAME);
				if (!existsSync(candidate)) continue;
				filePath = candidate;
				expectedName = entry;
			} else if (entry.endsWith(".md")) {
				filePath = path;
				expectedName = basename(entry, ".md");
			}
		} catch {
			continue;
		}
		if (!filePath || !expectedName) continue;

		let content: string;
		try {
			content = readFileSync(filePath, "utf8");
		} catch (error) {
			errors.push(`${filePath}: ${error instanceof Error ? error.message : String(error)}`);
			continue;
		}
		const parsed = parseAgentDefinition(content, filePath);
		if (!parsed.agent) {
			errors.push(parsed.error ?? `${filePath}: invalid agent`);
			continue;
		}
		if (parsed.agent.name !== expectedName) {
			errors.push(`${filePath}: frontmatter name "${parsed.agent.name}" does not match folder "${expectedName}"`);
			continue;
		}
		agents.set(parsed.agent.name, parsed.agent);
	}
	return { agents: [...agents.values()], errors };
}

/**
 * The --tools allowlist for a child, or undefined to keep Pi's default set.
 * Agents decide their own tools; a bare shared-read child is read-only; a bare
 * worktree child keeps Pi's defaults. The child tools are always present.
 */
export function resolveChildTools(mode: SubagentMode, agent?: AgentDefinition): string[] | undefined {
	let base: string[] | undefined;
	if (agent) base = agent.tools;
	else if (mode === "shared-read") base = [...READ_ONLY_TOOLS];
	if (base === undefined) return undefined;
	const set = new Set(base);
	for (const tool of CHILD_TOOLS) set.add(tool);
	return [...set];
}

/** One line per agent for the subagent_start description. */
export function formatAgentCatalog(agents: AgentDefinition[]): string {
	if (agents.length === 0) return "No agent definitions found.";
	return agents.map((agent) => `${agent.name}: ${agent.description}`).join("; ");
}
