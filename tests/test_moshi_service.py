"""Exercise service control with fake managers, files, and process probes."""

import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("moshi_service", ROOT / "moshi/service.py")
service = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = service
SPEC.loader.exec_module(service)


class MoshiServiceTests(unittest.TestCase):
    def setUp(self):
        self.home = Path("/home/moshi-test")
        self.system = "Darwin"
        self.plists = set()
        self.jobs = {}
        self.units = {}
        self.process = False
        self.calls = []
        self.failures = {}
        self.failure_effects = {}
        self.install_service = None
        self.start_succeeds = True
        patches = [
            patch.object(service.platform, "system", side_effect=lambda: self.system),
            patch.object(service.os, "getuid", return_value=501),
            patch.object(service.Path, "home", return_value=self.home),
            patch.object(service.shutil, "which", return_value="/tools/moshi-hook"),
            patch.object(service.os, "access", return_value=False),
            patch.object(service.subprocess, "run", side_effect=self.run_command),
            patch.object(service, "WAIT_ATTEMPTS", 1),
        ]
        for item in patches:
            item.start()
            self.addCleanup(item.stop)
        # autospec preserves the Path argument when testing fake files.
        self.file_patch = patch.object(
            service.Path, "is_file", autospec=True,
            side_effect=lambda path: str(path) in self.plists,
        )
        self.file_patch.start()
        self.addCleanup(self.file_patch.stop)

    def plist(self, label):
        path = self.home / "Library/LaunchAgents" / f"{label}.plist"
        self.plists.add(str(path))
        return path

    def unit(self, name, running=False, executable="/tools/moshi-hook", load="loaded"):
        self.units[name] = {
            "LoadState": load,
            "ActiveState": "active" if running else "inactive",
            "SubState": "running" if running else "dead",
            "ExecStart": f"{{ path={executable} ; argv[]={executable} serve ; ignore_errors=no ; }}",
        }

    def result(self, args, code=0, stdout="", stderr=""):
        return subprocess.CompletedProcess(args, code, stdout, stderr)

    def run_command(self, args, **kwargs):
        args = tuple(args)
        self.calls.append(args)
        self.assertEqual(kwargs, {
            "capture_output": True, "text": True, "check": False,
            "timeout": service.COMMAND_TIMEOUT,
        })
        if args in self.failures:
            if args in self.failure_effects:
                self.failure_effects[args]()
            if isinstance(self.failures[args], Exception):
                raise self.failures[args]
            return self.result(args, **self.failures[args])
        if args[0] == "pgrep":
            self.assertEqual(args, ("pgrep", "-u", "501", "-x", "moshi(-hook)?"))
            return self.result(args, 0 if self.process else 1, stdout="123\n" if self.process else "")
        if args[0] == "launchctl":
            operation = args[1]
            if operation == "print":
                label = args[2].split("/")[-1]
                state = self.jobs.get(label)
                if state is None:
                    return self.result(args, 113, stderr=f'Could not find service "{label}" in domain for user gui: 501')
                return self.result(args, stdout=f"state = {state}\n" + ("pid = 123\n" if state == "running" else ""))
            if operation == "bootstrap":
                label = Path(args[3]).stem
                if self.start_succeeds:
                    self.jobs[label] = "running"
            elif operation == "kickstart" and self.start_succeeds:
                self.jobs[args[2].split("/")[-1]] = "running"
            elif operation == "bootout":
                self.jobs.pop(args[2].split("/")[-1], None)
            elif operation not in ("enable", "disable", "kickstart"):
                self.fail(f"unexpected launchctl operation: {args}")
            return self.result(args)
        if args[0] == "systemctl":
            self.assertEqual(args[1], "--user")
            operation = args[2]
            name = args[3] if operation == "show" else args[-1]
            if operation == "show":
                values = self.units.get(name, {"LoadState": "not-found"})
                return self.result(args, stdout="\n".join(f"{key}={value}" for key, value in values.items()))
            self.assertIn(operation, ("enable", "disable", "stop"))
            if operation != "stop":
                self.assertEqual(args[3], "--now")
            if operation == "enable" and self.start_succeeds:
                self.units[name].update(ActiveState="active", SubState="running")
            if operation in ("disable", "stop"):
                self.units[name].update(ActiveState="inactive", SubState="dead")
            return self.result(args)
        if args == ("/tools/moshi-hook", "service", "install"):
            if self.install_service:
                if self.system == "Darwin":
                    self.plist(self.install_service)
                    self.jobs[self.install_service] = "running"
                else:
                    self.unit(self.install_service, running=True)
            return self.result(args)
        self.fail(f"unexpected subprocess (no real commands are permitted): {args}")

    def invoke(self, action):
        output, error = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(error):
            status = service.main([action])
        return status, output.getvalue(), error.getvalue()

    def mutations(self):
        return [args for args in self.calls if args[0] not in ("pgrep",) and not (
            args[0] == "launchctl" and args[1] == "print"
        ) and not (args[0] == "systemctl" and args[2] == "show")]

    def test_status_is_read_only_and_reports_unconfigured(self):
        status, output, error = self.invoke("status")
        self.assertEqual(status, 0, error)
        self.assertIn("not configured", output)
        self.assertEqual(self.mutations(), [])

    def test_status_reports_stopped_and_unmanaged_running_process(self):
        self.plist(service.LAUNCH_AGENTS[0])
        self.assertIn("stopped", self.invoke("status")[1])
        self.process = True
        self.assertIn("running (unmanaged", self.invoke("status")[1])
        self.assertEqual(self.mutations(), [])

    def test_macos_on_bootstraps_existing_unloaded_agent(self):
        label = service.LAUNCH_AGENTS[0]
        path = self.plist(label)
        status, output, error = self.invoke("on")
        self.assertEqual(status, 0, error)
        self.assertIn("started", output)
        self.assertEqual(self.mutations(), [
            ("launchctl", "enable", f"gui/501/{label}"),
            ("launchctl", "bootstrap", "gui/501", str(path)),
        ])

    def test_macos_on_uses_loaded_homebrew_job_without_plist(self):
        label = service.LAUNCH_AGENTS[1]
        self.jobs[label] = "running"
        self.assertEqual(self.invoke("on")[0], 0)
        self.assertEqual(self.mutations(), [
            ("launchctl", "enable", f"gui/501/{label}"),
            ("launchctl", "kickstart", f"gui/501/{label}"),
        ])

    def test_macos_off_disables_and_unloads_all_known_backends(self):
        for label in service.LAUNCH_AGENTS:
            self.plist(label)
            self.jobs[label] = "running"
        status, output, error = self.invoke("off")
        self.assertEqual(status, 0, error)
        self.assertIn("stopped", output)
        self.assertEqual(self.mutations(), [
            command for label in service.LAUNCH_AGENTS for command in (
                ("launchctl", "disable", f"gui/501/{label}"),
                ("launchctl", "bootout", f"gui/501/{label}"),
            )
        ])
        self.assertEqual(self.invoke("off")[0], 0)

    def test_off_still_stops_other_services_after_permission_failure(self):
        first, second = service.LAUNCH_AGENTS[:2]
        self.plist(first)
        self.plist(second)
        self.failures[("launchctl", "disable", f"gui/501/{first}")] = {
            "code": 1, "stderr": "Operation not permitted",
        }
        status, _, error = self.invoke("off")
        self.assertEqual(status, 1)
        self.assertIn("Operation not permitted", error)
        self.assertIn(("launchctl", "bootout", f"gui/501/{first}"), self.calls)
        self.assertIn(("launchctl", "disable", f"gui/501/{second}"), self.calls)

    def test_off_ignores_only_missing_job_bootout_failure(self):
        label = service.LAUNCH_AGENTS[0]
        self.plist(label)
        command = ("launchctl", "bootout", f"gui/501/{label}")
        self.failures[command] = {"code": 3, "stderr": "Boot-out failed: 3: No such process"}
        self.assertEqual(self.invoke("off")[0], 0)
        self.failures[command] = {"code": 1, "stderr": "Operation not permitted"}
        self.assertEqual(self.invoke("off")[0], 1)

    def test_status_manager_errors_are_unknown_not_unconfigured(self):
        label = service.LAUNCH_AGENTS[0]
        self.failures[("launchctl", "print", f"gui/501/{label}")] = {
            "code": 1, "stderr": "Operation not permitted",
        }
        status, output, error = self.invoke("status")
        self.assertEqual(status, 1)
        self.assertIn("unknown", output)
        self.assertIn("Operation not permitted", error)
        self.assertEqual(self.mutations(), [])

    def test_off_stops_valid_job_after_another_alias_cannot_be_inspected(self):
        first, second = service.LAUNCH_AGENTS[:2]
        self.failures[("launchctl", "print", f"gui/501/{first}")] = {
            "code": 1, "stderr": "Operation not permitted inspecting first alias",
        }
        self.jobs[second] = "running"
        status, _, error = self.invoke("off")
        self.assertEqual(status, 1)
        self.assertIn("Operation not permitted inspecting first alias", error)
        self.assertEqual(self.mutations(), [
            ("launchctl", "disable", f"gui/501/{second}"),
            ("launchctl", "bootout", f"gui/501/{second}"),
        ])
        self.assertNotIn(second, self.jobs)
        self.assertIn(("pgrep", "-u", "501", "-x", "moshi(-hook)?"), self.calls)

    def test_on_rejects_duplicate_services_before_mutation(self):
        for label in service.LAUNCH_AGENTS[:2]:
            self.plist(label)
        status, _, error = self.invoke("on")
        self.assertEqual(status, 1)
        self.assertIn("multiple", error)
        self.assertEqual(self.mutations(), [])

    def test_explicit_on_installs_only_service_and_verifies_running(self):
        self.install_service = service.LAUNCH_AGENTS[0]
        status, _, error = self.invoke("on")
        self.assertEqual(status, 0, error)
        self.assertIn(("/tools/moshi-hook", "service", "install"), self.mutations())
        binary_calls = [args for args in self.calls if args[0] == "/tools/moshi-hook"]
        self.assertEqual(binary_calls, [("/tools/moshi-hook", "service", "install")])

    def test_on_missing_binary_or_missing_installed_service_fails(self):
        service.shutil.which.return_value = None
        status, _, error = self.invoke("on")
        self.assertEqual(status, 1)
        self.assertIn("not installed", error)
        self.assertEqual(self.mutations(), [])
        service.shutil.which.return_value = "/tools/moshi-hook"
        status, _, error = self.invoke("on")
        self.assertEqual(status, 1)
        self.assertIn("did not configure", error)

    def test_on_surfaces_service_installer_failure(self):
        self.failures[("/tools/moshi-hook", "service", "install")] = {
            "code": 1, "stderr": "Homebrew service is installed; use brew services",
        }
        status, _, error = self.invoke("on")
        self.assertEqual(status, 1)
        self.assertIn("Homebrew service is installed", error)

    def test_on_requires_daemon_to_start(self):
        label = service.LAUNCH_AGENTS[0]
        self.plist(label)
        self.start_succeeds = False
        status, _, error = self.invoke("on")
        self.assertEqual(status, 1)
        self.assertIn("did not start", error)
        self.assertIn(("launchctl", "disable", f"gui/501/{label}"), self.calls)
        self.assertIn(("launchctl", "bootout", f"gui/501/{label}"), self.calls)

    def test_partial_bootstrap_failure_rolls_back_startup_and_running_job(self):
        label = service.LAUNCH_AGENTS[0]
        path = self.plist(label)
        bootstrap = ("launchctl", "bootstrap", "gui/501", str(path))
        self.failures[bootstrap] = {"code": 5, "stderr": "bootstrap failed after loading"}
        self.failure_effects[bootstrap] = lambda: self.jobs.update({label: "running"})
        status, _, error = self.invoke("on")
        self.assertEqual(status, 1)
        self.assertIn("bootstrap failed after loading", error)
        self.assertEqual(self.mutations(), [
            ("launchctl", "enable", f"gui/501/{label}"), bootstrap,
            ("launchctl", "disable", f"gui/501/{label}"),
            ("launchctl", "bootout", f"gui/501/{label}"),
        ])
        self.assertNotIn(label, self.jobs)

    def test_partial_installer_failure_discovers_and_stops_created_service(self):
        label = service.LAUNCH_AGENTS[0]
        install = ("/tools/moshi-hook", "service", "install")
        self.failures[install] = {"code": 1, "stderr": "installer failed after starting"}

        def partial_install():
            self.plist(label)
            self.jobs[label] = "running"

        self.failure_effects[install] = partial_install
        status, _, error = self.invoke("on")
        self.assertEqual(status, 1)
        self.assertIn("installer failed after starting", error)
        self.assertIn(("launchctl", "disable", f"gui/501/{label}"), self.calls)
        self.assertIn(("launchctl", "bootout", f"gui/501/{label}"), self.calls)
        self.assertNotIn(label, self.jobs)

    def test_startup_and_rollback_errors_both_remain_visible(self):
        label = service.LAUNCH_AGENTS[0]
        path = self.plist(label)
        self.failures[("launchctl", "bootstrap", "gui/501", str(path))] = {
            "code": 5, "stderr": "original bootstrap failure",
        }
        self.failures[("launchctl", "disable", f"gui/501/{label}")] = {
            "code": 1, "stderr": "rollback permission denied",
        }
        status, _, error = self.invoke("on")
        self.assertEqual(status, 1)
        self.assertIn("original bootstrap failure", error)
        self.assertIn("rollback failed", error)
        self.assertIn("rollback permission denied", error)
        self.assertIn(("launchctl", "bootout", f"gui/501/{label}"), self.calls)

    def test_timed_out_inspection_reports_unknown_without_mutations(self):
        command = ("launchctl", "print", f"gui/501/{service.LAUNCH_AGENTS[0]}")
        self.failures[command] = subprocess.TimeoutExpired(command, service.COMMAND_TIMEOUT)
        status, output, error = self.invoke("status")
        self.assertEqual(status, 1)
        self.assertIn("unknown", output)
        self.assertIn("timed out after 15 seconds", error)
        self.assertEqual(self.mutations(), [])

    def test_timed_out_bootstrap_is_rolled_back(self):
        label = service.LAUNCH_AGENTS[0]
        path = self.plist(label)
        command = ("launchctl", "bootstrap", "gui/501", str(path))
        self.failures[command] = subprocess.TimeoutExpired(command, service.COMMAND_TIMEOUT)
        self.failure_effects[command] = lambda: self.jobs.update({label: "running"})
        status, _, error = self.invoke("on")
        self.assertEqual(status, 1)
        self.assertIn("timed out", error)
        self.assertIn(("launchctl", "disable", f"gui/501/{label}"), self.calls)
        self.assertIn(("launchctl", "bootout", f"gui/501/{label}"), self.calls)
        self.assertNotIn(label, self.jobs)

    def test_off_does_not_kill_unmanaged_process(self):
        self.process = True
        status, _, error = self.invoke("off")
        self.assertEqual(status, 1)
        self.assertIn("still running", error)
        self.assertEqual(self.mutations(), [])

    def test_on_does_not_install_over_unmanaged_process(self):
        self.process = True
        status, _, error = self.invoke("on")
        self.assertEqual(status, 1)
        self.assertIn("unmanaged", error)
        self.assertEqual(self.mutations(), [])

    def test_linux_controls_all_validated_unit_names(self):
        self.system = "Linux"
        for name in service.SYSTEMD_UNITS:
            self.unit(name, running=True)
        status, output, error = self.invoke("status")
        self.assertEqual(status, 0, error)
        self.assertIn("running", output)
        self.assertEqual(self.mutations(), [])
        status, _, error = self.invoke("off")
        self.assertEqual(status, 0, error)
        self.assertEqual(self.mutations(), [
            ("systemctl", "--user", "disable", "--now", name)
            for name in service.SYSTEMD_UNITS
        ])

    def test_linux_on_enables_and_starts_existing_service(self):
        self.system = "Linux"
        self.unit("moshi-hook.service")
        status, _, error = self.invoke("on")
        self.assertEqual(status, 0, error)
        self.assertEqual(self.mutations(), [("systemctl", "--user", "enable", "--now", "moshi-hook.service")])

    def test_linux_disable_failure_still_attempts_stop(self):
        self.system = "Linux"
        name = "moshi-hook.service"
        self.unit(name, running=True)
        self.failures[("systemctl", "--user", "disable", "--now", name)] = {
            "code": 1, "stderr": "Access denied disabling unit",
        }
        status, _, error = self.invoke("off")
        self.assertEqual(status, 1)
        self.assertIn("Access denied disabling unit", error)
        self.assertIn(("systemctl", "--user", "stop", name), self.calls)
        self.assertEqual(self.units[name]["ActiveState"], "inactive")

    def test_on_can_poll_transitional_service_without_treating_it_as_unmanaged(self):
        self.system = "Linux"
        starting = service.Service("moshi-hook.service", running=False, state="starting")
        running = service.Service("moshi-hook.service", running=True, state="running")
        with patch.object(service, "WAIT_ATTEMPTS", 2), patch.object(service.time, "sleep") as sleep, \
                patch.object(service.Manager, "services", side_effect=[[starting], [starting], [running]]), \
                patch.object(service.Manager, "start") as start, \
                patch.object(service.Manager, "process_running") as probe:
            status, _, error = self.invoke("on")
        self.assertEqual(status, 0, error)
        start.assert_called_once_with(starting)
        sleep.assert_called_once_with(0.1)
        probe.assert_not_called()

    def test_linux_explicit_on_can_install_native_service(self):
        self.system = "Linux"
        self.install_service = "moshi-hook.service"
        status, _, error = self.invoke("on")
        self.assertEqual(status, 0, error)
        self.assertIn(("/tools/moshi-hook", "service", "install"), self.calls)

    def test_linux_refuses_unrelated_service_using_moshi_name(self):
        self.system = "Linux"
        self.unit("homebrew.moshi-hook.service", executable="/tools/unrelated")
        status, output, error = self.invoke("status")
        self.assertEqual(status, 1)
        self.assertIn("unknown", output)
        self.assertIn("not a Moshi serve command", error)
        self.assertEqual(self.mutations(), [])

    def test_linux_off_stops_native_service_despite_an_unrelated_alias(self):
        self.system = "Linux"
        native, unrelated = service.SYSTEMD_UNITS[:2]
        self.unit(native, running=True)
        self.unit(unrelated, running=True, executable="/tools/unrelated")
        status, _, error = self.invoke("off")
        self.assertEqual(status, 1)
        self.assertIn(f"refusing to control {unrelated}", error)
        self.assertEqual(self.mutations(), [
            ("systemctl", "--user", "disable", "--now", native),
        ])
        self.assertEqual(self.units[native]["ActiveState"], "inactive")
        self.assertEqual(self.units[unrelated]["ActiveState"], "active")
        self.assertIn(("pgrep", "-u", "501", "-x", "moshi(-hook)?"), self.calls)

    def test_linux_reports_transitional_states_and_off_can_stop_them(self):
        self.system = "Linux"
        self.unit("moshi-hook.service")
        for active, text in (("activating", "starting"), ("deactivating", "stopping")):
            with self.subTest(active=active):
                self.units["moshi-hook.service"]["ActiveState"] = active
                status, output, error = self.invoke("status")
                self.assertEqual(status, 0, error)
                self.assertIn(text, output)
                status, _, error = self.invoke("off")
                self.assertEqual(status, 0, error)
                self.assertIn(("systemctl", "--user", "disable", "--now", "moshi-hook.service"), self.calls)

    def test_linux_bus_errors_and_unknown_state_are_unknown(self):
        self.system = "Linux"
        self.unit("moshi-hook.service")
        self.units["moshi-hook.service"]["ActiveState"] = "unexpected"
        status, output, error = self.invoke("status")
        self.assertEqual(status, 1)
        self.assertIn("unknown", output)
        self.assertIn("cannot determine", error)
        first_show = self.calls[0]
        self.failures[first_show] = {"code": 1, "stderr": "Failed to connect to bus: No medium found"}
        status, output, error = self.invoke("status")
        self.assertEqual(status, 1)
        self.assertIn("unknown", output)
        self.assertIn("Failed to connect to bus", error)

    def test_process_probe_failure_cannot_claim_stopped(self):
        self.failures[("pgrep", "-u", "501", "-x", "moshi(-hook)?")] = {
            "code": 2, "stderr": "process list unavailable",
        }
        status, output, error = self.invoke("status")
        self.assertEqual(status, 1)
        self.assertIn("unknown", output)
        self.assertIn("process list unavailable", error)
        self.assertEqual(self.invoke("off")[0], 1)

    def test_unsupported_platform_never_runs_manager_or_binary(self):
        self.system = "Windows"
        status, output, error = self.invoke("status")
        self.assertEqual(status, 1)
        self.assertIn("unknown", output)
        self.assertIn("unsupported platform", error)
        self.assertEqual(self.calls, [])

    def test_binary_lookup_uses_adapter_fallback_paths(self):
        service.shutil.which.return_value = None
        service.os.access.return_value = True
        path = self.home / ".local/bin/moshi-hook"
        self.plists.add(str(path))
        self.assertEqual(service.find_binary(), str(path))


if __name__ == "__main__":
    unittest.main()
