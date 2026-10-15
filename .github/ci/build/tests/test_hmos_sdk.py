import hashlib
import io
import json
import os
import shutil
import subprocess
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
PROJECT = ROOT / "HarmonyOS/APIExample"


def har_bytes(version: str) -> bytes:
    metadata = json.dumps({"name": "@shengwang/rtc-full", "version": version}).encode()
    result = io.BytesIO()
    with tarfile.open(fileobj=result, mode="w:gz") as archive:
        info = tarfile.TarInfo("package/oh-package.json5")
        info.size = len(metadata)
        archive.addfile(info, io.BytesIO(metadata))
    return result.getvalue()


class PrepareSdkTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.project = Path(self.directory.name) / "project"
        (self.project / "entry/libs").mkdir(parents=True)
        shutil.copy2(PROJECT / "prepare_sdk.sh", self.project / "prepare_sdk.sh")
        shutil.copy2(PROJECT / "sdk-release.env", self.project / "sdk-release.env")
        self.har = self.project / "entry/libs/AgoraRtcSdk.har"

    def run_prepare(self, *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(self.project / "prepare_sdk.sh")],
            capture_output=True,
            text=True,
            env={**os.environ, **(env or {})},
            check=False,
        )

    def test_matching_har_is_kept_without_a_download(self) -> None:
        contents = har_bytes("4.6.3")
        self.har.write_bytes(contents)
        result = self.run_prepare()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(contents, self.har.read_bytes())

    def test_other_version_is_not_overwritten(self) -> None:
        contents = har_bytes("4.6.70")
        self.har.write_bytes(contents)
        result = self.run_prepare()
        self.assertNotEqual(0, result.returncode)
        self.assertIn("HARMONY_SDK_FORCE=1", result.stderr)
        self.assertEqual(contents, self.har.read_bytes())

    def test_download_checks_digest_and_installs_har(self) -> None:
        with tempfile.TemporaryDirectory() as fixture_dir:
            fixture = Path(fixture_dir)
            sdk_zip = fixture / "sdk.zip"
            expected_har = har_bytes("4.6.3")
            with zipfile.ZipFile(sdk_zip, "w") as archive:
                archive.writestr("release/rtc/sdk/AgoraRtcSdk.har", expected_har)
            digest = hashlib.sha256(sdk_zip.read_bytes()).hexdigest()
            (self.project / "sdk-release.env").write_text(
                f"HARMONY_SDK_VERSION=4.6.3\nHARMONY_SDK_URL=https://example.invalid/sdk.zip\nHARMONY_SDK_SHA256={digest}\n"
            )
            bin_dir = fixture / "bin"
            bin_dir.mkdir()
            curl = bin_dir / "curl"
            curl.write_text(
                "#!/bin/sh\n"
                'while [ "$#" -gt 0 ]; do\n'
                '  if [ "$1" = "--output" ]; then output="$2"; shift; fi\n'
                '  shift\n'
                'done\n'
                'cp "$TEST_SDK_ZIP" "$output"\n'
            )
            curl.chmod(0o755)
            env = {"PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}", "TEST_SDK_ZIP": str(sdk_zip)}
            result = self.run_prepare(env=env)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual(expected_har, self.har.read_bytes())

            self.har.unlink()
            (self.project / "sdk-release.env").write_text(
                "HARMONY_SDK_VERSION=4.6.3\nHARMONY_SDK_URL=https://example.invalid/sdk.zip\n"
                f"HARMONY_SDK_SHA256={'0' * 64}\n"
            )
            result = self.run_prepare(env=env)
            self.assertNotEqual(0, result.returncode)
            self.assertFalse(self.har.exists())


class PackageSdkTest(unittest.TestCase):
    def test_source_package_uses_selected_har_and_omits_local_files(self) -> None:
        with tempfile.TemporaryDirectory() as fixture_dir:
            root = Path(fixture_dir)
            build_dir = root / ".github/ci/build"
            build_dir.mkdir(parents=True)
            shutil.copy2(ROOT / ".github/ci/build/build_hmos.sh", build_dir / "build_hmos.sh")
            project = root / "HarmonyOS/APIExample"
            (project / "entry/libs").mkdir(parents=True)
            (project / ".idea").mkdir()
            (project / "entry/build").mkdir()
            (project / "entry/.preview").mkdir()
            (project / "README.md").write_text("new example")
            key_center = project / "entry/src/main/ets/common/KeyCenter.ets"
            key_center.parent.mkdir(parents=True)
            key_center.write_text(
                "export const AppID: string = '" + "0123456789abcdef" * 2 + "'\n"
                "export const AppCertificate: string = 'local-only'\n"
            )
            (project / ".idea/local.xml").write_text("local state")
            (project / "entry/build/output.hap").write_text("generated")
            (project / "entry/.preview/KeyCenter.ts").write_text("generated")
            (project / "entry/libs/old.har").write_bytes(har_bytes("4.6.70"))

            sdk_har = har_bytes("4.6.3")
            sdk_zip = root / "sdk.zip"
            with zipfile.ZipFile(sdk_zip, "w") as archive:
                archive.writestr("release/rtc/sdk/AgoraRtcSdk.har", sdk_har)
                archive.writestr("release/rtc/samples/API-Example/old.txt", "stale")
            bin_dir = root / "bin"
            bin_dir.mkdir()
            curl = bin_dir / "curl"
            curl.write_text(
                "#!/bin/sh\n"
                'while [ "$#" -gt 0 ]; do\n'
                '  if [ "$1" = "--output" ]; then output="$2"; shift; fi\n'
                '  shift\n'
                'done\n'
                'cp "$TEST_SDK_ZIP" "$output"\n'
            )
            curl.chmod(0o755)
            output = root / "artifacts"
            output.mkdir()
            env = {
                **os.environ,
                "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
                "TEST_SDK_ZIP": str(sdk_zip),
                "sdk_url": "https://example.invalid/sdk.zip",
                "compile_project": "false",
                "WORKSPACE": str(output),
                "BUILD_NUMBER": "test",
            }
            result = subprocess.run(
                ["bash", str(build_dir / "build_hmos.sh")],
                capture_output=True, text=True, env=env, check=False,
            )
            self.assertEqual(0, result.returncode, result.stderr)
            packages = list(output.glob("APIExample_test_4.6.3_*.zip"))
            self.assertEqual(1, len(packages))
            with zipfile.ZipFile(packages[0]) as archive:
                files = archive.namelist()
                prefix = "release/rtc/samples/API-Example/"
                self.assertIn(prefix + "README.md", files)
                self.assertNotIn(prefix + "old.txt", files)
                self.assertNotIn(prefix + ".idea/local.xml", files)
                self.assertNotIn(prefix + "entry/build/output.hap", files)
                self.assertNotIn(prefix + "entry/.preview/KeyCenter.ts", files)
                self.assertNotIn(prefix + "entry/libs/old.har", files)
                self.assertEqual(sdk_har, archive.read(prefix + "entry/libs/AgoraRtcSdk.har"))
                self.assertEqual(
                    "export const AppID: string = '<#YOUR AppId#>'\nexport const AppCertificate: string = ''\n",
                    archive.read(prefix + "entry/src/main/ets/common/KeyCenter.ets").decode(),
                )
            self.assertIn("0123456789abcdef", key_center.read_text())


if __name__ == "__main__":
    unittest.main()
