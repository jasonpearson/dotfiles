import * as fs from 'node:fs';
import * as path from 'node:path';
import { homedir } from 'node:os';
import { randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';

export const MAX_WINDOWS = 4;
export const rootDir = () => path.resolve(process.env.PI_SUBAGENTS_DIR || path.join(process.env.PI_CODING_AGENT_DIR || path.join(homedir(), '.pi/agent'), 'subagents'));
export const run = (file, args, cwd) => execFileSync(file, args, { cwd, env: { ...process.env }, encoding: 'utf8', timeout: 15000, maxBuffer: 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'] }).trim();
export function privateDir(dir) {
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
  const stat = fs.lstatSync(dir);
  if (!stat.isDirectory() || stat.isSymbolicLink() || (process.getuid && stat.uid !== process.getuid()) || (stat.mode & 0o077)) throw new Error(`Expected private, owned directory: ${dir}`);
}
export function atomic(file, data) {
  const tmp = `${file}.${randomUUID()}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(data, null, 2) + '\n', { mode: 0o600, flag: 'wx' });
  fs.renameSync(tmp, file);
}
export function readJSON(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); }
  catch (error) { if (error.code === 'ENOENT') return fallback; throw error; }
}
export function jobDir(id) {
  if (!/^[a-f0-9-]{36}$/.test(id)) throw new Error('Use a full job UUID from subagent_status.');
  return path.join(rootDir(), id);
}
export function metaFor(id) {
  const dir = jobDir(id), base = readJSON(path.join(dir, 'job.json'));
  if (!base || base.id !== id) throw new Error(`Unknown job: ${id}`);
  return { ...base, ...readJSON(path.join(dir, 'current.json'), {}) };
}
export function runtimeDir(id) {
  const { runID } = metaFor(id);
  if (!runID) return jobDir(id); // Legacy jobs retain their original records.
  if (!/^[a-f0-9-]{36}$/.test(runID)) throw new Error('Invalid launch identity');
  return path.join(jobDir(id), 'runs', runID);
}
function tmux(meta, args) { return run('tmux', ['-S', meta.socket, ...args]); }
export function paneFor(meta) {
  const dir = runtimeDir(meta.id);
  return readJSON(path.join(dir, 'pane.json'))?.pane || readJSON(path.join(dir, 'state.json'))?.pane;
}
export function paneOwned(meta, allowDead = false) {
  const pane = paneFor(meta);
  if (!pane) return false;
  try {
    const actual = tmux(meta, ['display-message', '-p', '-t', pane, '#{pid}|#{@pi_subagent_id}|#{@pi_subagent_run}|#{pane_dead}']);
    const prefix = `${meta.serverPid}|${meta.id}|${meta.runID || ''}|`;
    return actual === prefix + '0' || (allowDead && actual === prefix + '1');
  } catch { return false; }
}
export const paneAlive = meta => paneOwned(meta);
export function inspect(id) {
  const meta = metaFor(id), dir = runtimeDir(id), started = meta.started || meta.created;
  const state = readJSON(path.join(dir, 'state.json'), { status: 'starting', updated: started });
  const exit = readJSON(path.join(dir, 'exit.json'));
  const alive = paneAlive(meta);
  const stale = Date.now() - (state.heartbeat || started) > 15000;
  let status = state.status;
  if (exit || !alive) status = Date.now() - started < 15000 && !exit ? 'starting' : (state.status === 'parking' ? 'parked' : 'closed');
  else if (stale) status = 'unresponsive';
  return { ...meta, ...state, status, alive, pane: paneFor(meta), exit, runtimeDir: dir, jobDir: jobDir(id), session: path.join(jobDir(id), 'session.jsonl'), report: readJSON(path.join(jobDir(id), 'report.json')) };
}
export function list(parent) {
  if (!fs.existsSync(rootDir())) return [];
  return fs.readdirSync(rootDir()).filter(id => /^[a-f0-9-]{36}$/.test(id) && fs.existsSync(path.join(jobDir(id), 'job.json'))).map(inspect).filter(j => !parent || j.parent === parent).sort((a, b) => a.created - b.created);
}
function withLaunchLock(fn) {
  if (process.env.PI_SUBAGENT_JOB) throw new Error('Recursive dispatch is disabled.');
  if (!process.env.TMUX || !process.env.TMUX_PANE) throw new Error('Dispatch/resume requires Pi inside tmux.');
  privateDir(rootDir());
  const lock = path.join(rootDir(), '.dispatch-lock');
  try { fs.mkdirSync(lock, { mode: 0o700 }); }
  catch { throw new Error(`Dispatch lock exists: ${lock}. Another launch may be active; after a crash, inspect before manually removing the empty lock directory.`); }
  try {
    if (list().filter(j => j.alive || j.status === 'starting').length >= MAX_WINDOWS) throw new Error(`Limit of ${MAX_WINDOWS} open child windows reached. Close a child or wait for completion.`);
    const socket = process.env.TMUX.split(',').slice(0, -2).join(',');
    if (!socket) throw new Error('Cannot identify parent tmux socket.');
    const target = run('tmux', ['-S', socket, 'display-message', '-p', '-t', process.env.TMUX_PANE, '#{socket_path}\n#{pid}\n#{session_id}']).split('\n');
    if (target.length !== 3) throw new Error('Cannot identify parent tmux server/session.');
    return fn(target);
  } finally { fs.rmdirSync(lock); }
}
function launch(base, target, { task, resumed, parent, parentSession, extension, launcher }) {
  const runID = randomUUID(), dir = path.join(jobDir(base.id), 'runs', runID);
  privateDir(dir); privateDir(path.join(dir, 'inbox')); privateDir(path.join(dir, 'acks'));
  const launchInfo = { runID, started: Date.now(), socket: target[0], serverPid: target[1], tmuxSession: target[2], parent, parentSession, extension, resumed };
  atomic(path.join(dir, 'launch.json'), launchInfo);
  if (task) fs.writeFileSync(path.join(dir, 'task.md'), task, { mode: 0o600, flag: 'wx' });
  atomic(path.join(jobDir(base.id), 'current.json'), launchInfo);
  const meta = metaFor(base.id);
  try {
    const env = ['-e', `PATH=${process.env.PATH}`, '-e', `PI_SUBAGENTS_DIR=${rootDir()}`];
    if (process.env.PI_CODING_AGENT_DIR) env.push('-e', `PI_CODING_AGENT_DIR=${process.env.PI_CODING_AGENT_DIR}`);
    // Multiple command arguments use tmux direct exec, never a shell program.
    const pane = tmux(meta, ['new-window', '-d', '-P', '-F', '#{pane_id}', '-t', `${target[2]}:`, '-n', `agent-${base.id.slice(0, 8)}`, '-c', meta.cwd, ...env, 'node', launcher, jobDir(base.id), runID]);
    atomic(path.join(dir, 'pane.json'), { pane });
    return inspect(base.id);
  } catch (error) {
    atomic(path.join(dir, 'exit.json'), { at: Date.now(), error: 'Launch failed; retained job/worktree require inspection.' });
    throw new Error(`Launch failed. Inspect retained files at ${dir}. ${error.message}`);
  }
}
export function dispatch({ name, task, cwd, workspace, branch, skills = [], model, provider, thinking, parent, parentSession, extension, launcher, piExecutable = 'pi' }) {
  return withLaunchLock(target => {
    cwd = fs.realpathSync(cwd);
    const skillPaths = skills.map(p => fs.realpathSync(path.resolve(cwd, p)));
    for (const skill of skillPaths) if (!fs.statSync(skill).isFile()) throw new Error(`Skill must name a SKILL.md file: ${skill}`);
    const id = randomUUID(), dir = jobDir(id);
    privateDir(dir);
    let workdir = cwd, baseCommit, warning;
    if (workspace === 'worktree') {
      const repo = run('git', ['rev-parse', '--show-toplevel'], cwd);
      baseCommit = run('git', ['rev-parse', '--verify', 'HEAD^{commit}'], repo);
      warning = run('git', ['status', '--porcelain'], repo) ? 'Worktree starts at HEAD; parent uncommitted/untracked files are NOT copied.' : undefined;
      branch ||= `subagent/${id}`;
      run('git', ['check-ref-format', '--branch', branch], repo);
      if (branch.startsWith('-')) throw new Error('Invalid branch name.');
      workdir = path.join(dir, 'worktree');
      run('git', ['worktree', 'add', '-b', branch, '--', workdir, baseCommit], repo);
    } else if (workspace !== 'shared-read') throw new Error('Unknown workspace mode.');
    else if (branch) throw new Error('A branch is only valid with worktree mode.');
    const meta = { id, name, parent, parentSession, sourceCwd: cwd, cwd: workdir, workspace, branch, baseCommit, warning, created: Date.now(), provider, model, thinking, skills: skillPaths, piExecutable, extension };
    atomic(path.join(dir, 'job.json'), meta);
    return launch(meta, target, { task, resumed: false, parent, parentSession, extension, launcher });
  });
}
export function resume(id, { task, parent, parentSession, extension, launcher }) {
  return withLaunchLock(target => {
    const job = inspect(id);
    if (job.alive || job.status === 'starting') throw new Error('Child is still open or starting. Message it instead, or wait for parking to finish.');
    // Refuse a second writer if a detached Pi survived the original pane/launcher.
    if (job.pid) {
      try { process.kill(job.pid, 0); throw new Error('Recorded child PID still exists; inspect it before resuming.'); }
      catch (error) { if (error.code !== 'ESRCH') throw error; }
    }
    if (!fs.statSync(job.session).isFile()) throw new Error('Saved session not found; refusing a fresh replacement.');
    const fd = fs.openSync(job.session, 'r');
    try {
      const buffer = Buffer.alloc(16384);
      const size = fs.readSync(fd, buffer, 0, buffer.length, 0);
      const header = JSON.parse(buffer.subarray(0, size).toString('utf8').split('\n')[0]);
      if (header.type !== 'session' || typeof header.id !== 'string' || (job.sessionID && header.id !== job.sessionID)) throw new Error('identity mismatch');
    } catch { throw new Error('Saved session header is invalid or its identity changed; refusing a fresh replacement.'); }
    finally { fs.closeSync(fd); }
    fs.accessSync(job.cwd);
    for (const skill of job.skills) fs.accessSync(skill);
    if (job.workspace === 'worktree' && run('git', ['branch', '--show-current'], job.cwd) !== job.branch) throw new Error('Retained worktree branch changed; refusing resume.');
    // A user may have enabled remain-on-exit; clear only a verified dead owned pane.
    if (paneOwned(job, true)) tmux(job, ['kill-pane', '-t', paneFor(job)]);
    return launch(job, target, { task, resumed: true, parent, parentSession, extension, launcher });
  });
}
export function enqueue(id, action, text, reportRevision) {
  const job = inspect(id);
  if (!job.alive || job.status === 'parking') throw new Error('Child is not accepting messages; inspect status, then use subagent_resume after it closes.');
  const command = { id: randomUUID(), action, text, reportRevision, created: Date.now() };
  const dir = runtimeDir(id);
  atomic(path.join(dir, 'inbox', `${command.created}-${command.id}.json`), command);
  return { job: id, command: command.id, status: 'queued', acknowledgement: path.join(dir, 'acks', `${command.id}.json`) };
}
export function requestPark(id) {
  const job = inspect(id);
  if (job.status !== 'done' || !job.report?.revision || !fs.existsSync(job.session)) return;
  const file = path.join(job.runtimeDir, 'park-request.json');
  const previous = readJSON(file);
  if (previous?.revision === job.report.revision) return;
  const queued = enqueue(id, 'park', undefined, job.report.revision);
  atomic(file, { revision: job.report.revision, ...queued });
}
export function close(id) {
  const meta = metaFor(id);
  if (!paneOwned(meta, true)) throw new Error('Owned pane not found. Refusing to close anything.');
  tmux(meta, ['kill-pane', '-t', paneFor(meta)]);
  return { id, status: 'pane closed', retained: jobDir(id) };
}
