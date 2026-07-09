import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
VALIDATOR = REPO_ROOT / "docs/ai-engineering/tools/validate_acceptance_manifest.py"


def dispatch_for(role):
    return {
        "mode": "codex-subagent",
        "run_id": f"agent-run-{role}",
        "prompt": f"role-prompts/{role}.md",
        "prompt_sha256": "a" * 64,
        "artifact": f"role-artifacts/{role}.json",
        "artifact_sha256": "b" * 64,
        "evidence": f"{role} agent completed independently.",
    }


def base_manifest():
    role_results = {
        "product": {"status": "PASS"},
        "architecture": {"status": "PASS"},
        "reference": {"status": "PASS"},
        "implementation": {"status": "PASS"},
        "review": {"status": "PASS"},
        "test": {"status": "PASS"},
        "ux": {"status": "PASS"},
    }
    for role, result in role_results.items():
        result["evidence"] = f"{role} gate evidence"

    role_artifacts = {
        "product": {
            "agent_id": "product-agent-1",
            "dispatch": dispatch_for("product"),
            "summary": "Product scenario and non-goals are explicit.",
            "output": {
                "scenario": "Add Windows basic audio-only join parity.",
                "target": "windows/",
                "key_apis": ["joinChannel", "setAudioProfile"],
                "non_goals": ["Device smoke"],
            },
        },
        "architecture": {
            "agent_id": "architecture-agent-1",
            "dispatch": dispatch_for("architecture"),
            "summary": "Architecture constraints are scoped to Windows.",
            "output": {
                "platform_project": "windows/",
                "key_constraints": ["Windows only"],
                "files_allowed": ["windows/"],
            },
        },
        "reference": {
            "agent_id": "reference-agent-1",
            "dispatch": dispatch_for("reference"),
            "summary": "Reference contract extracted from Android full Join channel audio.",
            "output": {
                "source_case": "Android/APIExample/app/src/main/java/io/agora/api/example/examples/basic/JoinChannelAudio.java",
                "contract_result": "PASS",
                "parity_checklist_result": "PASS",
            },
        },
        "implementation": {
            "agent_id": "implementation-agent-1",
            "dispatch": dispatch_for("implementation"),
            "summary": "Implementation changed expected workflow files.",
            "output": {
                "query_cases": "No existing Windows basic audio-only join case.",
                "upsert_case": "Updated workflow only.",
                "files_changed": ["AGENTS.md", "docs/ai-engineering/knowledge-index.md"],
                "matrix_update": "Windows Join channel audio MISSING to PARTIAL.",
            },
        },
        "review": {
            "agent_id": "review-agent-1",
            "dispatch": dispatch_for("review"),
            "summary": "Review found no blocking issue.",
            "output": {
                "result": "PASS",
                "findings": ["No blocking findings."],
                "parity_checklist": "Reference behavior is represented in the manifest.",
            },
        },
        "test": {
            "agent_id": "test-agent-1",
            "dispatch": dispatch_for("test"),
            "summary": "Required static tests passed.",
            "output": {
                "commands": ["python3 docs/ai-engineering/tools/validate_acceptance_manifest.py manifest.json"],
                "reference_contract_result": "PASS",
                "parity_checklist_result": "PASS",
                "build_result": "PASS",
            },
        },
        "ux": {
            "agent_id": "ux-agent-1",
            "dispatch": dispatch_for("ux"),
            "summary": "UX entry point is consistent with adjacent samples.",
            "output": {
                "entry_point": "Basic -> Join channel audio",
                "notes": "Matches adjacent Windows cases.",
            },
        },
    }

    return {
        "version": 1,
        "final_status": "PASS",
        "product": {
            "scenario": "Add Windows basic audio-only join parity.",
            "target": "windows/",
            "non_goals": ["Device smoke"],
        },
        "reference": {
            "required": True,
            "source_case": "Android/APIExample/app/src/main/java/io/agora/api/example/examples/basic/JoinChannelAudio.java",
            "contract_result": "PASS",
            "parity_checklist_result": "PASS",
        },
        "architecture": {
            "platform_project": "windows/",
            "key_constraints": ["Windows only"],
        },
        "implementation": {
            "files_changed": ["AGENTS.md", "docs/ai-engineering/knowledge-index.md"],
            "skills_docs_used": [".agent/skills/api-example-release-iteration/SKILL.md"],
            "matrix_updates": [
                {
                    "feature": "Join channel audio",
                    "platform_unit": "Windows",
                    "from": "MISSING",
                    "to": "PARTIAL",
                    "evidence": "Build/static parity pass; device smoke pending.",
                }
            ],
        },
        "review": {
            "result": "PASS",
            "findings": [],
        },
        "testing": {
            "commands": [
                {
                    "command": "python3 docs/ai-engineering/tools/validate_acceptance_manifest.py manifest.json",
                    "result": "PASS",
                }
            ],
            "skipped_checks": [],
            "reference_contract_result": "PASS",
            "parity_checklist_result": "PASS",
            "build_result": "PASS",
        },
        "release": {
            "required": False,
            "checks": [],
            "skipped_checks": [],
        },
        "ux": {
            "entry_point": "Basic -> Join channel audio",
            "notes": "Matches adjacent Windows cases.",
        },
        "knowledge_updates": [
            {
                "source": "Review finding",
                "impact_platforms": ["Windows"],
                "symptom": "Parity case could compile while using the wrong SDK enum.",
                "root_cause": "Similar target-project sample replaced the source reference contract.",
                "guardrail": "Extract source reference contract before implementation.",
                "verification": "Review enum and overload values against source case.",
                "updated_at": "2026-07-08",
            }
        ],
        "role_results": role_results,
        "role_artifacts": role_artifacts,
    }


class AcceptanceManifestValidatorTest(unittest.TestCase):
    def run_validator(self, manifest):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(manifest, handle)
            manifest_path = handle.name
        try:
            return subprocess.run(
                [sys.executable, str(VALIDATOR), manifest_path],
                cwd=REPO_ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
        finally:
            Path(manifest_path).unlink(missing_ok=True)

    def test_valid_manifest_passes(self):
        result = self.run_validator(base_manifest())

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("Acceptance manifest valid", result.stdout)

    def test_failed_role_forces_blocked_final_status(self):
        manifest = base_manifest()
        manifest["role_results"]["review"] = {"status": "FAIL"}

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("review", result.stderr)
        self.assertIn("final_status", result.stderr)

    def test_done_matrix_update_requires_reference_parity_and_build_pass(self):
        manifest = base_manifest()
        manifest["implementation"]["matrix_updates"][0]["to"] = "DONE"
        manifest["testing"]["build_result"] = "BLOCKED"

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DONE", result.stderr)
        self.assertIn("build_result", result.stderr)

    def test_done_matrix_update_requires_clean_pass_final_status(self):
        manifest = base_manifest()
        manifest["final_status"] = "PASS WITH RISKS"
        manifest["implementation"]["matrix_updates"][0]["to"] = "DONE"
        manifest["testing"]["skipped_checks"] = [
            {
                "name": "device smoke",
                "reason": "Device is unavailable.",
            }
        ]

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DONE", result.stderr)
        self.assertIn("final_status=PASS", result.stderr)

    def test_changed_file_paths_must_exist(self):
        manifest = base_manifest()
        manifest["implementation"]["files_changed"] = ["does/not/exist.md"]

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does/not/exist.md", result.stderr)

    def test_waived_role_requires_reason(self):
        manifest = base_manifest()
        manifest["role_results"]["ux"] = {"status": "WAIVED", "evidence": "UX is not affected."}

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("waiver_reason", result.stderr)

    def test_role_requires_evidence(self):
        manifest = base_manifest()
        del manifest["role_results"]["review"]["evidence"]

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("role_results.review.evidence", result.stderr)

    def test_role_artifacts_are_required_for_multi_agent_acceptance(self):
        manifest = base_manifest()
        del manifest["role_artifacts"]

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("role_artifacts", result.stderr)

    def test_role_artifact_agent_ids_must_be_unique(self):
        manifest = base_manifest()
        manifest["role_artifacts"]["review"]["agent_id"] = "product-agent-1"

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("agent_id", result.stderr)
        self.assertIn("review", result.stderr)

    def test_role_artifact_output_contract_is_required(self):
        manifest = base_manifest()
        del manifest["role_artifacts"]["product"]["output"]["key_apis"]

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("role_artifacts.product.output.key_apis", result.stderr)

    def test_role_artifact_dispatch_is_required_for_multi_agent_acceptance(self):
        manifest = base_manifest()
        del manifest["role_artifacts"]["product"]["dispatch"]

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("role_artifacts.product.dispatch", result.stderr)

    def test_pending_dispatch_cannot_pass_final_acceptance(self):
        manifest = base_manifest()
        manifest["role_artifacts"]["product"]["dispatch"] = {
            "mode": "pending",
            "prompt": "role-prompts/product.md",
            "artifact": "role-artifacts/product.json",
        }

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("dispatch.mode=pending", result.stderr)
        self.assertIn("final_status=BLOCKED", result.stderr)

    def test_accepted_dispatch_must_use_codex_subagent(self):
        manifest = base_manifest()
        manifest["role_artifacts"]["product"]["dispatch"]["mode"] = "codex-thread"

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("role_artifacts.product.dispatch.mode=codex-thread", result.stderr)
        self.assertIn("codex-subagent", result.stderr)

    def test_accepted_dispatch_requires_subagent_provenance(self):
        manifest = base_manifest()
        del manifest["role_artifacts"]["product"]["dispatch"]["run_id"]
        del manifest["role_artifacts"]["product"]["dispatch"]["prompt_sha256"]
        del manifest["role_artifacts"]["product"]["dispatch"]["artifact_sha256"]

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("role_artifacts.product.dispatch.run_id", result.stderr)
        self.assertIn("role_artifacts.product.dispatch.prompt_sha256", result.stderr)
        self.assertIn("role_artifacts.product.dispatch.artifact_sha256", result.stderr)

    def test_lead_agent_cannot_own_role_artifact(self):
        manifest = base_manifest()
        manifest["role_artifacts"]["product"]["agent_id"] = "lead-agent"

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("lead-agent", result.stderr)

    def test_template_with_placeholders_is_not_valid_manifest(self):
        result = subprocess.run(
            [
                sys.executable,
                str(VALIDATOR),
                "docs/ai-engineering/templates/acceptance-manifest-template.json",
            ],
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("placeholder", result.stderr)

    def test_review_result_fail_requires_blocked_final_status(self):
        manifest = base_manifest()
        manifest["review"]["result"] = "FAIL"

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("review.result", result.stderr)
        self.assertIn("final_status", result.stderr)

    def test_reference_section_result_must_match_testing_result(self):
        manifest = base_manifest()
        manifest["reference"]["contract_result"] = "FAIL"

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("reference.contract_result", result.stderr)
        self.assertIn("testing.reference_contract_result", result.stderr)

    def test_release_check_fail_requires_blocked_final_status(self):
        manifest = base_manifest()
        manifest["release"]["required"] = True
        manifest["release"]["checks"] = [
            {
                "name": "Jenkins node reachability",
                "result": "FAIL",
                "evidence": "Node is offline.",
            }
        ]
        manifest["role_results"]["release"] = {
            "status": "PASS",
            "evidence": "Release gate evidence.",
        }

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("release.checks[0].result=FAIL", result.stderr)
        self.assertIn("final_status", result.stderr)

    def test_failed_test_command_requires_blocked_final_status(self):
        manifest = base_manifest()
        manifest["testing"]["commands"][0]["result"] = "FAIL"

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("testing.commands[0].result=FAIL", result.stderr)
        self.assertIn("final_status", result.stderr)

    def test_failed_build_result_requires_blocked_final_status(self):
        manifest = base_manifest()
        manifest["testing"]["build_result"] = "FAIL"

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("testing.build_result=FAIL", result.stderr)
        self.assertIn("final_status", result.stderr)

    def test_skipped_test_command_cannot_use_pass_final_status(self):
        manifest = base_manifest()
        manifest["testing"]["commands"][0]["result"] = "SKIPPED"
        manifest["testing"]["commands"][0]["reason"] = "Device is unavailable."

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("testing.commands[0].result=SKIPPED", result.stderr)
        self.assertIn("final_status=PASS", result.stderr)

    def test_skipped_build_result_cannot_use_pass_final_status(self):
        manifest = base_manifest()
        manifest["testing"]["build_result"] = "SKIPPED"

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("testing.build_result=SKIPPED", result.stderr)
        self.assertIn("final_status=PASS", result.stderr)

    def test_skipped_release_check_cannot_use_pass_final_status(self):
        manifest = base_manifest()
        manifest["release"]["required"] = True
        manifest["release"]["checks"] = [
            {
                "name": "Jenkins node reachability",
                "result": "SKIPPED",
                "reason": "Jenkins credentials are unavailable.",
            }
        ]
        manifest["role_results"]["release"] = {
            "status": "PASS",
            "evidence": "Release gate evidence.",
        }

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("release.checks[0].result=SKIPPED", result.stderr)
        self.assertIn("final_status=PASS", result.stderr)

    def test_skipped_test_command_can_use_pass_with_risks_when_reason_is_recorded(self):
        manifest = base_manifest()
        manifest["final_status"] = "PASS WITH RISKS"
        manifest["testing"]["commands"][0]["result"] = "SKIPPED"
        manifest["testing"]["commands"][0]["reason"] = "Device smoke is unavailable."

        result = self.run_validator(manifest)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)

    def test_knowledge_update_requires_durable_doc_change(self):
        manifest = base_manifest()
        manifest["implementation"]["files_changed"] = ["AGENTS.md"]

        result = self.run_validator(manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("knowledge_updates", result.stderr)
        self.assertIn("durable", result.stderr)

    def test_knowledge_update_allows_repository_skill_change(self):
        manifest = base_manifest()
        manifest["implementation"]["files_changed"] = [".agent/skills/api-example-release-iteration/SKILL.md"]

        result = self.run_validator(manifest)

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)


if __name__ == "__main__":
    unittest.main()
