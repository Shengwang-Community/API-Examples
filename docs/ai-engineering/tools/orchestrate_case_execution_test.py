import json
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
ORCHESTRATOR = REPO_ROOT / "docs/ai-engineering/tools/orchestrate_case_execution.py"
VALIDATOR = REPO_ROOT / "docs/ai-engineering/tools/validate_acceptance_manifest.py"


def dispatch_for(role):
    return {
        "mode": "codex-subagent",
        "run_id": f"agent-run-{role}",
        "prompt": f"role-prompts/{role}.md",
        "artifact": f"role-artifacts/{role}.json",
        "evidence": f"{role} agent completed independently.",
    }


class CaseExecutionOrchestratorTest(unittest.TestCase):
    def write_matrix(self):
        handle = tempfile.NamedTemporaryFile("w", suffix=".md", delete=False)
        handle.write(
            textwrap.dedent(
                """
                | Feature | SDK Family | Key APIs | Android full | Android Compose | Windows | Notes |
                | --- | --- | --- | --- | --- | --- | --- |
                | Join channel audio | Full RTC | `joinChannel`, `setAudioProfile` | `DONE(basic/JoinChannelAudio.java)` | `DONE(samples/JoinChannelAudio.kt)` | `MISSING` | Windows has no basic audio-only join case. |

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

    def run_orchestrator(self, *args):
        return subprocess.run(
            [sys.executable, str(ORCHESTRATOR), *args],
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def init_workspace(self, matrix_path, run_dir):
        result = self.run_orchestrator(
            "init",
            "--matrix",
            str(matrix_path),
            "--feature",
            "Join channel audio",
            "--platform-unit",
            "Windows",
            "--run-dir",
            str(run_dir),
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_init_creates_execution_workspace_with_role_tasks(self):
        matrix_path = self.write_matrix()
        with tempfile.TemporaryDirectory() as tmpdir:
            run_dir = Path(tmpdir) / "join-audio-run"

            self.init_workspace(matrix_path, run_dir)

            package = json.loads((run_dir / "execution-package.json").read_text())
            manifest = json.loads((run_dir / "acceptance-manifest.json").read_text())
            role_files = sorted(path.name for path in (run_dir / "role-artifacts").glob("*.json"))
            prompt_files = sorted(path.name for path in (run_dir / "role-prompts").glob("*.md"))

            self.assertEqual(package["execution_unit"]["feature"], "Join channel audio")
            self.assertEqual(package["execution_unit"]["platform_unit"], "Windows")
            self.assertEqual(manifest["final_status"], "BLOCKED")
            self.assertIn("role_artifacts", manifest)
            self.assertEqual(manifest["role_artifacts"]["product"]["dispatch"]["mode"], "pending")
            self.assertEqual(
                role_files,
                [
                    "architecture.json",
                    "implementation.json",
                    "product.json",
                    "reference.json",
                    "review.json",
                    "test.json",
                    "ux.json",
                ],
            )
            self.assertEqual(
                prompt_files,
                [
                    "architecture.md",
                    "implementation.md",
                    "product.md",
                    "reference.md",
                    "review.md",
                    "test.md",
                    "ux.md",
                ],
            )

    def test_init_can_select_highest_priority_unit_without_explicit_filter(self):
        matrix_path = self.write_matrix()
        with tempfile.TemporaryDirectory() as tmpdir:
            run_dir = Path(tmpdir) / "auto-run"

            result = self.run_orchestrator(
                "init",
                "--matrix",
                str(matrix_path),
                "--run-dir",
                str(run_dir),
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            package = json.loads((run_dir / "execution-package.json").read_text())
            self.assertEqual(package["execution_unit"]["feature"], "Join channel audio")
            self.assertEqual(package["execution_unit"]["platform_unit"], "Windows")

    def test_assemble_merges_role_artifacts_validates_manifest_and_updates_matrix(self):
        matrix_path = self.write_matrix()
        with tempfile.TemporaryDirectory() as tmpdir:
            run_dir = Path(tmpdir) / "join-audio-run"
            self.init_workspace(matrix_path, run_dir)

            self.write_passing_role_artifacts(run_dir, matrix_path)
            result = self.run_orchestrator(
                "assemble",
                "--run-dir",
                str(run_dir),
                "--matrix",
                str(matrix_path),
                "--final-status",
                "PASS",
            )

            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            final_manifest_path = run_dir / "final-acceptance-manifest.json"
            final_manifest = json.loads(final_manifest_path.read_text())
            self.assertEqual(final_manifest["final_status"], "PASS")
            self.assertEqual(final_manifest["review"]["result"], "PASS")
            self.assertEqual(final_manifest["testing"]["build_result"], "PASS")
            self.assertEqual(final_manifest["role_results"]["product"]["status"], "PASS")
            self.assertEqual(final_manifest["role_artifacts"]["product"]["agent_id"], "product-agent-1")
            self.assertEqual(final_manifest["role_artifacts"]["product"]["dispatch"]["mode"], "codex-subagent")
            self.assertRegex(final_manifest["role_artifacts"]["product"]["dispatch"]["prompt_sha256"], r"^[0-9a-f]{64}$")
            self.assertRegex(final_manifest["role_artifacts"]["product"]["dispatch"]["artifact_sha256"], r"^[0-9a-f]{64}$")
            self.assertIn("`PARTIAL(Static parity pass; device smoke pending.)`", matrix_path.read_text())

            validation = subprocess.run(
                [sys.executable, str(VALIDATOR), str(final_manifest_path)],
                cwd=REPO_ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            self.assertEqual(validation.returncode, 0, validation.stderr + validation.stdout)

    def test_assemble_with_default_blocked_artifacts_does_not_update_matrix(self):
        matrix_path = self.write_matrix()
        original_matrix = matrix_path.read_text()
        with tempfile.TemporaryDirectory() as tmpdir:
            run_dir = Path(tmpdir) / "join-audio-run"
            self.init_workspace(matrix_path, run_dir)

            result = self.run_orchestrator(
                "assemble",
                "--run-dir",
                str(run_dir),
                "--matrix",
                str(matrix_path),
                "--final-status",
                "BLOCKED",
            )

            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            final_manifest_path = run_dir / "final-acceptance-manifest.json"
            final_manifest = json.loads(final_manifest_path.read_text())
            self.assertEqual(final_manifest["final_status"], "BLOCKED")
            self.assertEqual(final_manifest["implementation"]["files_changed"], [])
            self.assertEqual(final_manifest["implementation"]["matrix_updates"], [])
            self.assertEqual(matrix_path.read_text(), original_matrix)

    def write_passing_role_artifacts(self, run_dir, matrix_path):
        artifacts = {
            "product": {
                "agent_id": "product-agent-1",
                "dispatch": dispatch_for("product"),
                "status": "PASS",
                "evidence": "Product gate passed.",
                "summary": "Scenario and non-goals are explicit.",
                "output": {
                    "scenario": "Backfill Windows basic audio-only join API example.",
                    "target": "windows/",
                    "key_apis": ["joinChannel", "setAudioProfile"],
                    "non_goals": ["Device smoke"],
                },
            },
            "architecture": {
                "agent_id": "architecture-agent-1",
                "dispatch": dispatch_for("architecture"),
                "status": "PASS",
                "evidence": "Architecture gate passed.",
                "summary": "Windows target is valid.",
                "output": {
                    "platform_project": "windows/",
                    "key_constraints": ["Windows only"],
                    "files_allowed": ["windows/"],
                },
            },
            "reference": {
                "agent_id": "reference-agent-1",
                "dispatch": dispatch_for("reference"),
                "status": "PASS",
                "evidence": "Reference contract extracted.",
                "summary": "Android full Join channel audio is the source contract.",
                "output": {
                    "source_case": "Android/APIExample/app/src/main/java/io/agora/api/example/examples/basic/JoinChannelAudio.java",
                    "contract_result": "PASS",
                    "parity_checklist_result": "PASS",
                },
            },
            "implementation": {
                "agent_id": "implementation-agent-1",
                "dispatch": dispatch_for("implementation"),
                "status": "PASS",
                "evidence": "Implementation gate passed.",
                "summary": "Implementation artifacts are recorded.",
                "output": {
                    "query_cases": "No existing Windows basic audio-only join case.",
                    "upsert_case": "Case implementation completed by role agent.",
                    "files_changed": [str(matrix_path)],
                    "matrix_update": {
                        "feature": "Join channel audio",
                        "platform_unit": "Windows",
                        "from": "MISSING",
                        "to": "PARTIAL",
                        "to_cell": "PARTIAL(Static parity pass; device smoke pending.)",
                        "evidence": "Static parity pass; device smoke pending.",
                    },
                },
            },
            "review": {
                "agent_id": "review-agent-1",
                "dispatch": dispatch_for("review"),
                "status": "PASS",
                "evidence": "Review gate passed.",
                "summary": "No blocking findings.",
                "output": {
                    "result": "PASS",
                    "findings": ["No blocking findings."],
                    "parity_checklist": "Reference behavior checked.",
                },
            },
            "test": {
                "agent_id": "test-agent-1",
                "dispatch": dispatch_for("test"),
                "status": "PASS",
                "evidence": "Test gate passed.",
                "summary": "Static validation passed.",
                "output": {
                    "commands": [
                        {
                            "command": "python3 docs/ai-engineering/tools/validate_acceptance_manifest.py manifest.json",
                            "result": "PASS",
                        }
                    ],
                    "reference_contract_result": "PASS",
                    "parity_checklist_result": "PASS",
                    "build_result": "PASS",
                    "skipped_checks": [],
                },
            },
            "ux": {
                "agent_id": "ux-agent-1",
                "dispatch": dispatch_for("ux"),
                "status": "PASS",
                "evidence": "UX gate passed.",
                "summary": "Entry point is clear.",
                "output": {
                    "entry_point": "Basic -> Join channel audio",
                    "notes": "Matches adjacent Windows samples.",
                },
            },
        }
        artifact_dir = run_dir / "role-artifacts"
        for role, artifact in artifacts.items():
            (artifact_dir / f"{role}.json").write_text(json.dumps(artifact, indent=2), encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
