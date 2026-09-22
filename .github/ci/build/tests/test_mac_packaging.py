"""Exercise the macOS packaging adapter without SDK downloads or signing credentials."""

import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[4]
MACOS = ROOT / "macOS"
PROJECT_VERSION = re.search(
    r"MARKETING_VERSION = ([^;]+);",
    (MACOS / "APIExample.xcodeproj/project.pbxproj").read_text(),
).group(1)
FAKE_TOOL = r'''
import json
import os
from pathlib import Path
import sys
import zipfile

tool = Path(sys.argv[0]).name
args = sys.argv[1:]
stage = tool
if tool == "xcodebuild":
    stage = "export" if "-exportArchive" in args else "archive"
with open(os.environ["COMMAND_LOG"], "a") as log:
    log.write(json.dumps([stage, args]) + "\n")
if os.environ.get("FAIL_STAGE") == stage:
    sys.exit(42)
if os.environ.get("OMIT_STAGE") == stage:
    sys.exit(0)

def option(name):
    return args[args.index(name) + 1]

if tool == "curl":
    with zipfile.ZipFile(option("-o"), "w") as bundle:
        bundle.writestr("AgoraBeautyMaterial.bundle/beauty_material_functional/config.json", "{}")
elif tool == "pod":
    Path("APIExample.xcworkspace").mkdir()
elif stage in ("archive", "export"):
    if stage == "archive":
        app = Path(option("-archivePath")) / "Products/Applications/APIExample.app"
    else:
        app = Path(option("-exportPath")) / "APIExample.app"
    (app / "Contents/MacOS").mkdir(parents=True)
    (app / "Contents/MacOS/APIExample").write_text("test executable")
elif tool == "ditto":
    app, output = map(Path, args[-2:])
    with zipfile.ZipFile(output, "w") as package:
        for path in app.rglob("*"):
            if path.is_file():
                package.write(path, path.relative_to(app.parent))
'''


class MacPackagingTest(unittest.TestCase):
    def run_packaging(self, *, fail="", omit="", branch="main", **env_overrides):
        scratch = tempfile.TemporaryDirectory(prefix="mac packaging ")
        self.addCleanup(scratch.cleanup)
        base = Path(scratch.name).resolve()
        project, workspace, bin_dir = (base / name for name in ("project", "workspace", "bin"))
        for directory in (project, workspace, bin_dir):
            directory.mkdir()
        for name in ("cloud_build.sh", "ExportOptions.plist", "APIExample.xcodeproj/project.pbxproj"):
            target = project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(MACOS / name, target)
        keycenter = project / "APIExample/Common/KeyCenter.swift"
        keycenter.parent.mkdir(parents=True)
        keycenter.write_text("static let AppId = <#YOUR AppId#>\n")
        (project / "APIExample/Resources").mkdir()
        # Cleanup must preserve archives belonging to other builds.
        (workspace / "unrelated.xcarchive").mkdir()
        for tool in ("curl", "pod", "xcodebuild", "codesign", "ditto"):
            executable = bin_dir / tool
            executable.write_text(f"#!{sys.executable}\n" + FAKE_TOOL)
            executable.chmod(0o755)
        command_log = base / "commands.jsonl"
        # Isolate from the developer's Jenkins variables and real credentials.
        env = {
            "PATH": f"{bin_dir}:/usr/bin:/bin:/usr/sbin:/sbin",
            "WORKSPACE": str(workspace),
            "BUILD_NUMBER": "61",
            "APP_ID": "0" * 32,
            "JFROG_API_KEY": "test-only-placeholder",
            "sdk_url": "https://example.invalid/sdk/4.7/test.zip",
            "api_examples_shengwang_branch": branch,
            "COMMAND_LOG": str(command_log),
            "FAIL_STAGE": fail,
            "OMIT_STAGE": omit,
        }
        env.update(env_overrides)
        result = subprocess.run(
            [str(project / "cloud_build.sh")], cwd=project, env=env,
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30,
        )
        calls = [json.loads(line) for line in command_log.read_text().splitlines()] if command_log.exists() else []
        return result, calls, workspace, project

    def test_success_exports_signed_app_package_with_matching_team(self):
        result, calls, workspace, project = self.run_packaging()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual([stage for stage, _ in calls], ["curl", "pod", "archive", "export", "codesign", "ditto"])
        options = plistlib.loads((project / "ExportOptions.plist").read_bytes())
        self.assertEqual(options["teamID"], "YS397FG5PA")
        self.assertEqual(options["signingStyle"], "automatic")
        self.assertEqual(options["method"], "debugging")
        archive_args = dict(calls)["archive"]
        self.assertIn(f"DEVELOPMENT_TEAM={options['teamID']}", archive_args)
        self.assertIn("CODE_SIGN_STYLE=Automatic", archive_args)
        self.assertIn("CODE_SIGN_IDENTITY=Apple Development", archive_args)
        export_args = dict(calls)["export"]
        self.assertEqual(export_args[export_args.index("-exportOptionsPlist") + 1], str(project / "ExportOptions.plist"))
        self.assertIn("--strict", dict(calls)["codesign"])
        packages = list(workspace.glob("*.app.zip"))
        self.assertEqual(len(packages), 1)
        with zipfile.ZipFile(packages[0]) as package:
            self.assertIn("APIExample.app/Contents/MacOS/APIExample", package.namelist())
        self.assertIn(f"OUTPUT_FILE: {packages[0]}", result.stdout)
        self.assertNotIn("0" * 32, result.stdout)
        self.assertTrue((workspace / "unrelated.xcarchive").is_dir())
        self.assertFalse((workspace / "APIExample_61.xcarchive").exists())
        self.assertFalse((workspace / "APIExample_61_export").exists())

    def test_command_failure_stops_before_later_stages(self):
        stages = ["curl", "pod", "archive", "export", "codesign", "ditto"]
        for stage in stages:
            with self.subTest(stage=stage):
                result, calls, workspace, _ = self.run_packaging(fail=stage)
                self.assertEqual(result.returncode, 42, result.stdout)
                self.assertEqual([name for name, _ in calls], stages[:stages.index(stage) + 1])
                self.assertNotIn("OUTPUT_FILE:", result.stdout)
                self.assertEqual(list(workspace.glob("*.app.zip")), [])

    def test_successful_command_without_artifact_fails(self):
        for stage, message in (
            ("pod", "No Xcode workspace found"),
            ("archive", "Archive does not contain"),
            ("export", "Xcode export did not produce"),
            ("ditto", "App package was not created"),
        ):
            with self.subTest(stage=stage):
                result, calls, workspace, _ = self.run_packaging(omit=stage)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertEqual(calls[-1][0], stage)
                self.assertIn(message, result.stdout)
                self.assertNotIn("OUTPUT_FILE:", result.stdout)
                self.assertEqual(list(workspace.glob("*.app.zip")), [])

    def test_version_validation_is_preserved(self):
        for branch in (f"refs/remotes/origin/dev/{PROJECT_VERSION}", "refs/heads/main"):
            with self.subTest(branch=branch):
                result, _, _, _ = self.run_packaging(branch=branch)
                self.assertEqual(result.returncode, 0, result.stdout)
        result, calls, _, _ = self.run_packaging(branch="dev/0.0.0")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Version mismatch", result.stdout)
        self.assertEqual(calls, [])

    def test_branch_name_environment_fallback(self):
        result, calls, _, _ = self.run_packaging(branch="", BRANCH_NAME="dev/0.0.0")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Version mismatch", result.stdout)
        self.assertEqual(calls, [])

    def test_required_inputs_fail_before_any_commands(self):
        for name in ("BUILD_NUMBER", "APP_ID", "JFROG_API_KEY"):
            with self.subTest(name=name):
                result, calls, _, _ = self.run_packaging(**{name: ""})
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn(f"{name} is required", result.stdout)
                self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
