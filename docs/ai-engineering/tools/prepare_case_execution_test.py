import json
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
RUNNER = REPO_ROOT / "docs/ai-engineering/tools/prepare_case_execution.py"
VALIDATOR = REPO_ROOT / "docs/ai-engineering/tools/validate_acceptance_manifest.py"


class CaseExecutionPreparationTest(unittest.TestCase):
    def run_runner(self, matrix_text, *args):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as handle:
            handle.write(matrix_text)
            matrix_path = handle.name
        try:
            return subprocess.run(
                [sys.executable, str(RUNNER), "--matrix", matrix_path, *args],
                cwd=REPO_ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
        finally:
            Path(matrix_path).unlink(missing_ok=True)

    def test_selects_highest_priority_unit_and_emits_execution_package(self):
        matrix = textwrap.dedent(
            """
            | Feature | SDK Family | Key APIs | Android full | Android Compose | Windows | Notes |
            | --- | --- | --- | --- | --- | --- | --- |
            | Join channel audio | Full RTC | `joinChannel`, `setAudioProfile` | `DONE(basic/JoinChannelAudio.java)` | `DONE(samples/JoinChannelAudio.kt)` | `MISSING` | Windows has no basic audio-only join case. |
            | Media metadata | Full RTC | `registerMediaMetadataObserver` | `DONE(advanced/MediaMetadata.java)` | `DONE(samples/MediaMetadata.kt)` | `PARTIAL(Advanced/Metadata; smoke pending)` | Runtime metadata smoke pending. |

            ## Confirmed Gaps

            | Gap | Affected Units | Severity |
            | --- | --- | --- |
            | Basic audio-only join channel | Windows | High - missing foundational case |
            | Media metadata | Windows | Medium - runtime smoke pending |
            """
        )

        result = self.run_runner(matrix)

        self.assertEqual(result.returncode, 0, result.stderr)
        package = json.loads(result.stdout)
        unit = package["execution_unit"]
        self.assertEqual(unit["feature"], "Join channel audio")
        self.assertEqual(unit["platform_unit"], "Windows")
        self.assertEqual(unit["priority"], 10)
        self.assertEqual(
            package["reference_contract"]["source_case"],
            "Android/APIExample/app/src/main/java/io/agora/api/example/examples/basic/JoinChannelAudio.java",
        )
        self.assertTrue((REPO_ROOT / package["reference_contract"]["source_case"]).exists())
        self.assertEqual(package["acceptance_manifest_seed"]["product"]["target"], "windows/")
        self.assertEqual(package["acceptance_manifest_seed"]["final_status"], "BLOCKED")
        self.assertEqual(
            [contract["role"] for contract in package["role_contracts"]],
            ["product", "architecture", "implementation", "review", "test", "ux"],
        )
        self.assertIn("target project upsert-case skill", " ".join(package["execution_steps"]))
        role_artifacts = package["acceptance_manifest_seed"]["role_artifacts"]
        self.assertEqual(
            sorted(role_artifacts),
            ["architecture", "implementation", "product", "reference", "review", "test", "ux"],
        )
        agent_ids = [artifact["agent_id"] for artifact in role_artifacts.values()]
        self.assertEqual(len(agent_ids), len(set(agent_ids)))
        self.assertIn("key_apis", role_artifacts["product"]["output"])

        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(package["acceptance_manifest_seed"], handle)
            manifest_path = handle.name
        try:
            validation = subprocess.run(
                [sys.executable, str(VALIDATOR), manifest_path],
                cwd=REPO_ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
        finally:
            Path(manifest_path).unlink(missing_ok=True)
        self.assertEqual(validation.returncode, 0, validation.stderr + validation.stdout)

    def test_can_filter_to_specific_feature_and_platform_unit(self):
        matrix = textwrap.dedent(
            """
            | Feature | SDK Family | Key APIs | Android full | Android Compose | Windows | Notes |
            | --- | --- | --- | --- | --- | --- | --- |
            | Join channel audio | Full RTC | `joinChannel` | `DONE(basic/JoinChannelAudio.java)` | `DONE(samples/JoinChannelAudio.kt)` | `MISSING` | Missing Windows case. |
            | Media metadata | Full RTC | `registerMediaMetadataObserver` | `DONE(advanced/MediaMetadata.java)` | `DONE(samples/MediaMetadata.kt)` | `MISSING` | Missing Windows metadata case. |

            ## Confirmed Gaps

            | Gap | Affected Units | Severity |
            | --- | --- | --- |
            | Basic audio-only join channel | Windows | High - missing foundational case |
            | Media metadata | Windows | Medium - full-RTC platform gap |
            """
        )

        result = self.run_runner(matrix, "--feature", "Media metadata", "--platform-unit", "Windows")

        self.assertEqual(result.returncode, 0, result.stderr)
        unit = json.loads(result.stdout)["execution_unit"]
        self.assertEqual(unit["feature"], "Media metadata")
        self.assertEqual(unit["platform_unit"], "Windows")


if __name__ == "__main__":
    unittest.main()
