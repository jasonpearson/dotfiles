import { spawn } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { atomic, readJSON, run } from './jobs.ts';

const dir = process.argv[2], runID = process.argv[3];
const runtime = runID ? path.join(dir, 'runs', runID) : dir;
const meta = { ...readJSON(path.join(dir, 'job.json')), ...readJSON(path.join(runtime, 'launch.json'), {}) };
try {
  run('tmux', ['-S', meta.socket, 'set-option', '-p', '-t', process.env.TMUX_PANE, '@pi_subagent_id', meta.id]);
  if (runID) run('tmux', ['-S', meta.socket, 'set-option', '-p', '-t', process.env.TMUX_PANE, '@pi_subagent_run', runID]);
  const args = ['--session', path.join(dir, 'session.jsonl'), '--name', meta.name, '-e', meta.extension];
  // Resume uses the saved session's model/thinking rather than resetting to launch defaults.
  if (!meta.resumed) {
    if (meta.provider) args.push('--provider', meta.provider);
    if (meta.model) args.push('--model', meta.model);
    if (meta.thinking) args.push('--thinking', meta.thinking);
  }
  for (const skill of meta.skills) args.push('--skill', skill);
  if (meta.workspace === 'shared-read') args.push('--tools', 'read,grep,find,ls,subagent_report');
  if (fs.existsSync(path.join(runtime, 'task.md'))) args.push('--', `@${path.join(runtime, 'task.md')}`);
  const env = { ...process.env, PI_SUBAGENT_JOB: meta.id, PI_SUBAGENT_RUN: runID || '' };
  for (const key of ['PI_SESSION_ID', 'PI_SESSION_FILE', 'PI_PROVIDER', 'PI_MODEL', 'PI_REASONING_LEVEL']) delete env[key];
  const child = spawn(meta.piExecutable, args, { cwd: meta.cwd, env, stdio: 'inherit' });
  child.on('error', error => {
    atomic(path.join(runtime, 'exit.json'), { at: Date.now(), error: error.message });
    process.exitCode = 1;
  });
  child.on('exit', (code, signal) => {
    atomic(path.join(runtime, 'exit.json'), { at: Date.now(), code, signal });
    process.exitCode = code ?? 1;
    // Pi has exited and flushed its session. Respect sibling panes; never kill-window.
    if (readJSON(path.join(runtime, 'state.json'))?.status === 'parking') {
      const expected = `${meta.serverPid}|${meta.id}|${runID || ''}`;
      try {
        const actual = run('tmux', ['-S', meta.socket, 'display-message', '-p', '-t', process.env.TMUX_PANE, '#{pid}|#{@pi_subagent_id}|#{@pi_subagent_run}']);
        if (actual === expected) run('tmux', ['-S', meta.socket, 'kill-pane', '-t', process.env.TMUX_PANE]);
      } catch { /* Pane/server may already be gone; session and exit record are retained. */ }
    }
  });
  for (const signal of ['SIGTERM', 'SIGHUP', 'SIGINT']) process.on(signal, () => child.kill(signal));
} catch (error) {
  atomic(path.join(runtime, 'exit.json'), { at: Date.now(), error: error.message });
  console.error(error.message);
  process.exitCode = 1;
}
