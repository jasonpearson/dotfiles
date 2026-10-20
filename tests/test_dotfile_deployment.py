"""Exercise real mise deployments using disposable checkouts and homes."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
MISE = shutil.which("mise")


@unittest.skipUnless(MISE, "requires mise >= 2026.10.4")
class DotfileDeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles deployment ")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.home = self.base / "home"
        self.home.mkdir()
        self.checkout = self.base / 'checkout with spaces "quoted"'
        self.checkout.mkdir()
        # Copy deployment sources only, excluding checkout metadata and local state.
        config = tomllib.loads((ROOT / "mise/config.toml").read_text())
        directories = {"mise"}
        for entry in config["dotfiles"].values():
            if source := entry.get("source"):
                directories.add(Path(source).parts[1])
        for directory in directories:
            shutil.copytree(ROOT / directory, self.checkout / directory)
        self.elsewhere = self.base / "elsewhere"
        self.elsewhere.mkdir()
        self.global_config = self.home / ".config/mise/config.toml"
        self.source_config = self.checkout / "mise/config.toml"
        self.env = dict(
            os.environ,
            HOME=str(self.home),
            XDG_CONFIG_HOME=str(self.home / ".config"),
            MISE_CONFIG_DIR=str(self.home / ".config/mise"),
            MISE_GLOBAL_CONFIG_FILE=str(self.global_config),
            MISE_DATA_DIR=str(self.home / "data"),
            MISE_CACHE_DIR=str(self.home / "cache"),
            MISE_STATE_DIR=str(self.home / "state"),
            MISE_TRUSTED_CONFIG_PATHS=str(self.base),
            GIT_CONFIG_NOSYSTEM="1",
        )
        self.env.pop("GIT_CONFIG_GLOBAL", None)

    def mise(self, *args, cwd=None):
        return subprocess.run(
            [MISE, *args], cwd=cwd or self.checkout, env=self.env,
            check=True, text=True, capture_output=True, timeout=30,
        )

    def test_global_deployment_and_self_reapply_work_outside_checkout(self):
        self.global_config.parent.mkdir(parents=True)
        local = self.global_config.with_name("config.local.toml")
        local.write_text('[env]\nDOTFILES_TEST_LOCAL = "preserved"\n')
        source_before = self.source_config.read_bytes()
        self.mise("dot", "apply", "--dry-run")
        self.assertFalse(self.global_config.exists())
        self.mise("dot", "apply", "--yes")
        self.assertFalse(self.global_config.is_symlink())
        first = self.global_config.read_bytes()
        generated = tomllib.loads(first.decode())
        self.assertEqual(generated["vars"]["dotfiles_config"], str(self.source_config))
        for target, entry in generated["dotfiles"].items():
            if source := entry.get("source"):
                self.assertTrue(Path(source).is_absolute(), target)
                self.assertTrue(Path(source).is_relative_to(self.checkout), target)
                self.assertTrue(Path(source).exists(), target)
        self.mise("dot", "apply", "--dry-run", cwd=self.elsewhere)
        self.mise("dot", "status", "--missing", cwd=self.elsewhere)
        self.mise("dot", "apply", "--yes", cwd=self.elsewhere)
        self.mise("dot", "apply", "--yes", "~/.config/mise/config.toml", cwd=self.elsewhere)
        self.assertEqual(self.global_config.read_bytes(), first)
        self.assertEqual(self.source_config.read_bytes(), source_before)
        self.assertEqual(local.read_text(), '[env]\nDOTFILES_TEST_LOCAL = "preserved"\n')

    def test_old_symlink_migrates_without_writing_through_to_checkout(self):
        current = self.source_config.read_text()
        template = self.checkout / "mise/global-config.tera"
        template_bytes = template.read_bytes()
        template.unlink()
        self.source_config.write_text(current.replace(
            '"~/.config/mise/config.toml" = { source = "../mise/global-config.tera", mode = "template" }',
            '"~/.config/mise" = { source = ".", mode = "symlink-each" }',
        ))
        self.mise("dot", "apply", "--yes", "~/.config/mise")
        self.assertTrue(self.global_config.is_symlink())
        self.source_config.write_text(current)
        template.write_bytes(template_bytes)
        self.mise("dot", "apply", "--dry-run", "~/.config/mise/config.toml")
        self.assertTrue(self.global_config.is_symlink())
        self.mise("dot", "apply", "--yes", "~/.config/mise/config.toml")
        self.assertFalse(self.global_config.is_symlink())
        self.assertEqual(self.source_config.read_text(), current)
        self.mise("dot", "apply", "--yes", "--prune", cwd=self.elsewhere)
        self.assertTrue(self.global_config.is_file())
        self.mise("dot", "status", "--missing", cwd=self.elsewhere)
        self.assertEqual(self.source_config.read_text(), current)

    def test_amend_skill_deploys_with_human_only_invocation(self):
        name = "ammend-commits"
        targets = (f"~/.agents/skills/{name}", f"~/.claude/skills/{name}")
        source = self.checkout / "agents/skills" / name
        self.mise("dot", "apply", "--dry-run", *targets)
        for target in targets:
            self.assertFalse((self.home / target.removeprefix("~/")).exists())
        self.mise("dot", "apply", "--yes", *targets)
        for target in targets:
            deployed = self.home / target.removeprefix("~/")
            self.assertTrue(deployed.is_symlink())
            self.assertEqual(deployed.resolve(), source)
            skill = (deployed / "SKILL.md").read_text()
            frontmatter = skill.split("---\n", 2)[1].splitlines()
            self.assertIn(f"name: {name}", frontmatter)
            self.assertIn("disable-model-invocation: true", frontmatter)
            self.assertEqual(
                (deployed / "agents/openai.yaml").read_text(),
                "policy:\n  allow_implicit_invocation: false\n",
            )
        # Reapplying the two skill targets must not deploy unrelated settings.
        self.mise("dot", "apply", "--yes", *targets)
        self.assertFalse((self.home / ".claude/settings.json").exists())
        self.assertFalse((self.home / ".pi/agent/settings.json").exists())

    def test_deployed_git_global_ignore_is_effective(self):
        self.mise("dot", "apply", "--dry-run", "~/.config/git")
        self.mise("dot", "apply", "--yes", "~/.config/git")
        project = self.home / "project"
        project.mkdir()
        subprocess.run(["git", "init", "--quiet"], cwd=project, env=self.env, check=True)
        (project / ".DS_Store").touch()
        result = subprocess.run(
            ["git", "check-ignore", "-v", ".DS_Store"], cwd=project, env=self.env,
            check=True, text=True, capture_output=True,
        )
        self.assertIn(".config/git/.gitignore:1:.DS_Store\t.DS_Store", result.stdout)


if __name__ == "__main__":
    unittest.main()
