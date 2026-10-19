#!/usr/bin/env python3
"""Control the Moshi user service without pairing or installing agent hooks."""

import argparse
from dataclasses import dataclass
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time


LAUNCH_AGENTS = (
    "app.getmoshi.moshi-hook",
    "sh.brew.moshi-hook",
    "homebrew.mxcl.moshi-hook",
)
SYSTEMD_UNITS = (
    "moshi-hook.service",
    "sh.brew.moshi-hook.service",
    "homebrew.moshi-hook.service",
)
WAIT_ATTEMPTS = 20
COMMAND_TIMEOUT = 15


def find_binary():
    binary = shutil.which("moshi-hook")
    if binary:
        return binary
    for path in (
        Path.home() / ".local/bin/moshi-hook", Path("/opt/homebrew/bin/moshi-hook"),
        Path("/usr/local/bin/moshi-hook"), Path("/opt/local/bin/moshi-hook"),
        Path.home() / "bin/moshi-hook",
    ):
        if path.is_file() and os.access(path, os.X_OK):
            return str(path)
    raise ServiceError("moshi-hook is not installed; install and pair Moshi on this personal computer first")


class ServiceError(Exception):
    pass


@dataclass
class Service:
    name: str
    running: bool
    loaded: bool = False
    path: Path | None = None
    state: str = "stopped"


def run(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True, check=False, timeout=COMMAND_TIMEOUT)
    except subprocess.TimeoutExpired as error:
        raise ServiceError(f"{' '.join(args)} timed out after {COMMAND_TIMEOUT} seconds") from error
    except OSError as error:
        raise ServiceError(f"cannot run {args[0]}: {error}") from error


def detail(result):
    return (result.stderr or result.stdout).strip() or f"exit status {result.returncode}"


def absent_launch_job(result):
    message = (result.stderr + result.stdout).lower()
    # Missing jobs are expected; permission and session-domain errors are not.
    return result.returncode != 0 and any(
        text in message for text in (
            "could not find service", "service is not loaded", "no such process",
        )
    ) and not any(text in message for text in ("permission denied", "not permitted"))


def checked(*args, allow_absent=False):
    result = run(*args)
    if result.returncode and not (allow_absent and absent_launch_job(result)):
        raise ServiceError(f"{' '.join(args)}: {detail(result)}")
    return result


class Manager:
    def __init__(self):
        self.system = platform.system()
        if self.system not in ("Darwin", "Linux"):
            raise ServiceError(f"unsupported platform: {self.system}; manage Moshi manually")
        self.uid = str(os.getuid())
        self.domain = f"gui/{self.uid}"

    def services(self, errors=None):
        names = LAUNCH_AGENTS if self.system == "Darwin" else SYSTEMD_UNITS
        inspect = self.launch_agent if self.system == "Darwin" else self.systemd_unit
        services = []
        for name in names:
            try:
                item = inspect(name)
                if item is not None:
                    services.append(item)
            except ServiceError as error:
                if errors is None:
                    raise
                errors.append(str(error))
        return services

    def launch_agent(self, label):
        path = Path.home() / "Library/LaunchAgents" / f"{label}.plist"
        exists = path.is_file()
        result = run("launchctl", "print", f"{self.domain}/{label}")
        if result.returncode:
            if not absent_launch_job(result):
                raise ServiceError(f"cannot inspect {label}: {detail(result)}")
            return Service(label, running=False, path=path) if exists else None
        state = re.search(r"^\s*state = (.+)$", result.stdout, re.MULTILINE)
        pid = re.search(r"^\s*pid = ([1-9][0-9]*)\s*$", result.stdout, re.MULTILINE)
        if not state and not pid:
            raise ServiceError(f"cannot determine whether {label} is running")
        running = bool(pid) or bool(state and state[1] == "running")
        return Service(
            label, running=running, state="running" if running else "stopped",
            loaded=True, path=path if exists else None,
        )

    def systemd_unit(self, name):
        result = run(
            "systemctl", "--user", "show", name,
            "--property=LoadState", "--property=ActiveState",
            "--property=SubState", "--property=ExecStart",
        )
        values = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
        if values.get("LoadState") == "not-found" and not result.stderr.strip():
            return None
        if result.returncode:
            raise ServiceError(f"cannot inspect {name}: {detail(result)}")
        if values.get("LoadState") == "masked":
            # Keep a masked service off; enable will give a useful error.
            return Service(name, running=False)
        if values.get("LoadState") != "loaded":
            raise ServiceError(f"cannot inspect {name}: unknown unit load state")
        # Homebrew has used several unit names. Only control one that
        # actually runs the Moshi daemon, rather than trusting its name.
        executable = re.search(r"(?:^|\{\s*)path=([^;]+?)\s*;", values.get("ExecStart", ""))
        argv = re.search(r"argv\[\]=([^;]+)", values.get("ExecStart", ""))
        if (not executable or Path(executable[1]).name not in ("moshi-hook", "moshi")
                or not argv or not re.search(r"(?:^|\s)serve(?:\s|$)", argv[1])):
            raise ServiceError(f"refusing to control {name}: ExecStart is not a Moshi serve command")
        active = values.get("ActiveState")
        sub = values.get("SubState")
        if (active == "active" and sub == "running") or active == "reloading":
            state = "running"
        elif active in ("inactive", "failed"):
            state = "stopped"
        else:
            state = {"activating": "starting", "deactivating": "stopping"}.get(active, "unknown")
        return Service(name, running=state == "running", loaded=True, state=state)

    def process_running(self):
        result = run("pgrep", "-u", self.uid, "-x", "moshi(-hook)?")
        if result.returncode not in (0, 1):
            raise ServiceError(f"cannot inspect Moshi processes: {detail(result)}")
        return result.returncode == 0

    def start(self, service):
        if self.system == "Linux":
            checked("systemctl", "--user", "enable", "--now", service.name)
            return
        label = f"{self.domain}/{service.name}"
        checked("launchctl", "enable", label)
        if service.loaded:
            checked("launchctl", "kickstart", label)
        else:
            if service.path is None:
                raise ServiceError(f"cannot start {service.name}: its LaunchAgent plist is missing")
            checked("launchctl", "bootstrap", self.domain, str(service.path))

    def stop(self, service):
        if self.system == "Linux":
            try:
                checked("systemctl", "--user", "disable", "--now", service.name)
            except ServiceError as error:
                # Disabling startup can fail separately from stopping a unit.
                try:
                    checked("systemctl", "--user", "stop", service.name)
                except ServiceError as stop_error:
                    raise ServiceError(f"{error}; {stop_error}") from error
                raise
            return
        label = f"{self.domain}/{service.name}"
        # Try bootout even when disable fails, so a policy error does not leave
        # an otherwise stoppable daemon running.
        errors = []
        for command, allow_absent in (("disable", False), ("bootout", True)):
            try:
                checked("launchctl", command, label, allow_absent=allow_absent)
            except ServiceError as error:
                errors.append(str(error))
        if errors:
            raise ServiceError("; ".join(errors))


def enable(manager, services):
    attempted = []
    install_attempted = False
    try:
        if not services:
            if manager.process_running():
                raise ServiceError("an unmanaged moshi or moshi-hook process is running; stop it manually before enabling the service")
            binary = find_binary()
            install_attempted = True
            checked(binary, "service", "install")
            services = manager.services()
            if not services:
                raise ServiceError("Moshi service installation did not configure a supported user service")
        if len(services) > 1:
            raise ServiceError("multiple Moshi user services are configured; keep one before enabling: "
                               + ", ".join(service.name for service in services))
        service = services[0]
        if service.state == "stopped" and manager.process_running():
            raise ServiceError("an unmanaged moshi or moshi-hook process is running; stop it manually before enabling the service")
        attempted.append(service)
        manager.start(service)
        for attempt in range(WAIT_ATTEMPTS):
            if any(item.name == service.name and item.running for item in manager.services()):
                break
            if attempt == WAIT_ATTEMPTS - 1:
                raise ServiceError(f"{service.name} did not start; inspect its service log before enabling Moshi")
            time.sleep(0.1)
        print(f"Moshi service: started ({service.name}).")
    except ServiceError as error:
        rollback_errors = []
        if install_attempted:
            # An installer can create or start a service before failing.
            try:
                known_names = {item.name for item in attempted}
                for item in manager.services():
                    if item.name not in known_names:
                        attempted.append(item)
            except ServiceError as inspect_error:
                rollback_errors.append(f"cannot inspect installed services for rollback: {inspect_error}")
        for item in attempted:
            try:
                manager.stop(item)
            except ServiceError as stop_error:
                rollback_errors.append(str(stop_error))
        if attempted or install_attempted:
            try:
                ensure_no_process(manager)
            except ServiceError as process_error:
                rollback_errors.append(str(process_error))
        suffix = "; rollback failed: " + "; ".join(rollback_errors) if rollback_errors else ""
        raise ServiceError(f"{error}{suffix}") from error


def ensure_no_process(manager):
    for attempt in range(WAIT_ATTEMPTS):
        if not manager.process_running():
            return
        if attempt < WAIT_ATTEMPTS - 1:
            time.sleep(0.1)
    raise ServiceError("a moshi or moshi-hook process is still running; stop its foreground process or other supervisor manually")


def control(action):
    manager = Manager()
    errors = []
    services = manager.services(errors=errors) if action == "off" else manager.services()
    if action == "status":
        if any(item.state == "unknown" for item in services):
            raise ServiceError("cannot determine the state of " + ", ".join(
                item.name for item in services if item.state == "unknown"
            ))
        active = [item for item in services if item.state != "stopped"]
        if active:
            groups = []
            for state in ("running", "starting", "stopping"):
                names = [item.name for item in active if item.state == state]
                if names:
                    groups.append(f"{state} ({', '.join(names)})")
            print(f"Moshi service: {'; '.join(groups)}.")
        elif manager.process_running():
            print("Moshi service: running (unmanaged moshi or moshi-hook process).")
        elif services:
            print(f"Moshi service: stopped ({', '.join(item.name for item in services)}).")
        else:
            print("Moshi service: not configured.")
        return
    if action == "on":
        enable(manager, services)
        return
    for service in services:
        try:
            manager.stop(service)
        except ServiceError as error:
            errors.append(str(error))
    try:
        ensure_no_process(manager)
    except ServiceError as error:
        errors.append(str(error))
    if errors:
        raise ServiceError("; ".join(errors))
    print("Moshi service: stopped." if services else "Moshi service: not configured.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("on", "off", "status"), nargs="?", default="status")
    args = parser.parse_args(argv)
    try:
        control(args.action)
    except ServiceError as error:
        if args.action == "status":
            print("Moshi service: unknown.")
        print(f"moshi service: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
