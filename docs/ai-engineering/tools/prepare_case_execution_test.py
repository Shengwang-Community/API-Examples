import json
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from prepare_case_execution import collect_sdk_version_checks, prepare_case_execution
from validate_acceptance_manifest import validate_manifest


PLATFORMS = ["android", "ios", "macos", "windows"]


class PrepareCaseExecutionTest(unittest.TestCase):
    TARGET_SDK_VERSION = "4.6.4"

    def write_matrix(self):
        handle = tempfile.NamedTemporaryFile("w", suffix=".md", delete=False)
        handle.write(
            textwrap.dedent(
                """
                | Feature | SDK Family | Key APIs | Android full | iOS UIKit | macOS | Windows | Notes |
                | --- | --- | --- | --- | --- | --- | --- | --- |
                | Join channel audio | Full RTC | `joinChannel`, `setAudioProfile` | `DONE(app/JoinChannelAudio.java)` | `DONE/APIExample/JoinChannelAudio.swift` | `PARTIAL(APIExample/JoinChannelAudio.swift)` | `MISSING` | Keep all official platforms aligned. |

                ## Confirmed Gaps

                | Gap | Affected Units | Severity |
                | --- | --- | --- |
                | Basic audio-only join channel | Windows | High - missing foundational case |
                """
            )
        )
        handle.close()
        self.addCleanup(lambda: Path(handle.name).unlink(missing_ok=True))
        return Path(handle.name)

    def test_prepares_one_requirement_with_four_platform_delivery_units(self):
        package = prepare_case_execution(
            self.write_matrix(),
            feature="Join channel audio",
            target_sdk_version=self.TARGET_SDK_VERSION,
        )

        manifest = package["acceptance_manifest_seed"]
        self.assertEqual(manifest["version"], 4)
        self.assertEqual(sorted(manifest["platforms"]), PLATFORMS)
        self.assertIn("contract", manifest)
        self.assertNotIn("roles", manifest)
        self.assertEqual(sorted(package["role_contracts"]), ["contract", "implementation", "verification"])
        self.assertEqual(sorted(manifest["contract"]["output"]["platform_targets"]), PLATFORMS)
        self.assertEqual(manifest["requirement"]["target_sdk_version"], self.TARGET_SDK_VERSION)
        self.assertTrue(manifest["release"]["required"])
        self.assertEqual(manifest["release"]["target_sdk_version"], self.TARGET_SDK_VERSION)
        self.assertEqual(manifest["release"]["qa_acceptance"]["result"], "BLOCKED")
        self.assertNotIn("publication_channel", manifest["requirement"])
        self.assertNotIn("publication", manifest["release"])
        for platform in PLATFORMS:
            unit = manifest["platforms"][platform]
            self.assertEqual(sorted(unit), ["implementation", "verification"])
            self.assertEqual(unit["implementation"]["dispatch"]["mode"], "pending")
            self.assertEqual(unit["verification"]["status"], "BLOCKED")
        self.assertEqual(validate_manifest(manifest), [])

    def test_platform_defaults_select_official_full_sdk_projects(self):
        package = prepare_case_execution(
            self.write_matrix(),
            feature="Join channel audio",
            target_sdk_version=self.TARGET_SDK_VERSION,
        )
        targets = package["acceptance_manifest_seed"]["contract"]["output"]["platform_targets"]

        self.assertEqual(targets["android"]["target_project"], "Android/APIExample/")
        self.assertEqual(targets["ios"]["target_project"], "iOS/APIExample/")
        self.assertEqual(targets["macos"]["target_project"], "macOS/")
        self.assertEqual(targets["windows"]["target_project"], "windows/")
        self.assertTrue(all(target["required"] for target in targets.values()))

    def test_selects_highest_priority_feature_when_omitted(self):
        package = prepare_case_execution(
            self.write_matrix(), target_sdk_version=self.TARGET_SDK_VERSION
        )

        self.assertEqual(package["requirement"]["feature"], "Join channel audio")
        self.assertEqual(package["requirement"]["key_apis"], ["joinChannel", "setAudioProfile"])

    def test_package_is_json_serializable(self):
        serialized = json.dumps(
            prepare_case_execution(
                self.write_matrix(), target_sdk_version=self.TARGET_SDK_VERSION
            )
        )
        self.assertIn('"version": 4', serialized)

    def test_prepares_new_requirement_not_yet_present_in_matrix(self):
        package = prepare_case_execution(
            self.write_matrix(),
            feature="Spatial audio",
            sdk_family="Full RTC",
            key_apis=["enableSpatialAudio"],
            target_sdk_version=self.TARGET_SDK_VERSION,
        )

        self.assertEqual(package["requirement"]["feature"], "Spatial audio")
        self.assertEqual(package["requirement"]["key_apis"], ["enableSpatialAudio"])
        self.assertEqual(sorted(package["acceptance_manifest_seed"]["platforms"]), PLATFORMS)

    def test_requires_target_sdk_version(self):
        with self.assertRaisesRegex(ValueError, "target_sdk_version is required"):
            prepare_case_execution(self.write_matrix(), feature="Join channel audio")

    def test_collects_live_sdk_version_evidence(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            sources = {
                "android": [("Android/gradle.properties", r"version=(\d+\.\d+\.\d+)")],
                "ios": [("iOS/Podfile", r"version=(\d+\.\d+\.\d+)")],
                "macos": [("macOS/Podfile", r"version=(\d+\.\d+\.\d+)")],
                "windows": [("windows/install.ps1", r"version=(\d+\.\d+\.\d+)")],
            }
            for entries in sources.values():
                path = root / entries[0][0]
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("version=4.6.4\n", encoding="utf-8")

            checks = collect_sdk_version_checks(
                self.TARGET_SDK_VERSION, repo_root=root, sources=sources
            )

            self.assertTrue(all(check["result"] == "PASS" for check in checks))
            self.assertTrue(
                all(
                    set(check["actual_versions"].values()) == {self.TARGET_SDK_VERSION}
                    for check in checks
                )
            )

            (root / "windows/install.ps1").write_text("version=4.6.2\n", encoding="utf-8")
            checks = collect_sdk_version_checks(
                self.TARGET_SDK_VERSION, repo_root=root, sources=sources
            )
            windows = next(check for check in checks if check["name"] == "sdk-version-windows")
            self.assertEqual(windows["result"], "BLOCKED")
            self.assertIn("4.6.2", windows["reason"])


if __name__ == "__main__":
    unittest.main()
