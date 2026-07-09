#!/usr/bin/env python3
"""Validate API Examples AI-engineering acceptance manifests."""

import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
FINAL_STATUSES = {"PASS", "PASS WITH RISKS", "BLOCKED"}
RESULT_STATUSES = {"PASS", "FAIL", "BLOCKED", "SKIPPED"}
ROLE_STATUSES = {"PASS", "FAIL", "BLOCKED", "WAIVED"}
MATRIX_STATUSES = {"DONE", "PARTIAL", "MISSING", "N/A", "UNKNOWN"}
REQUIRED_TOP_LEVEL = [
    "version",
    "final_status",
    "product",
    "architecture",
    "implementation",
    "review",
    "testing",
    "release",
    "ux",
    "role_results",
    "role_artifacts",
]
BASE_ROLES = ["product", "architecture", "implementation", "review", "test", "ux"]
LEAD_AGENT_IDS = {"lead", "lead-agent", "lead_agent", "main", "main-agent", "main_agent", "coordinator"}
ROLE_ARTIFACT_REQUIRED_OUTPUT = {
    "product": ["scenario", "target", "key_apis", "non_goals"],
    "architecture": ["platform_project", "key_constraints", "files_allowed"],
    "reference": ["source_case", "contract_result", "parity_checklist_result"],
    "implementation": ["query_cases", "upsert_case", "files_changed", "matrix_update"],
    "review": ["result", "findings", "parity_checklist"],
    "test": ["commands", "reference_contract_result", "parity_checklist_result", "build_result"],
    "ux": ["entry_point", "notes"],
    "release": ["checks"],
}
DISPATCH_MODES = {"codex-subagent", "pending"}
KNOWLEDGE_UPDATE_FIELDS = [
    "source",
    "impact_platforms",
    "symptom",
    "root_cause",
    "guardrail",
    "verification",
    "updated_at",
]
DURABLE_KNOWLEDGE_PATHS = {
    "docs/ai-engineering/knowledge-index.md",
    "docs/ai-engineering/release-iteration-gate.md",
    "docs/ai-engineering/release-known-issues.md",
    "docs/ai-engineering/case-maintenance-matrix.md",
}
PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def is_non_empty(value):
    return value is not None and value != "" and value != []


def has_placeholder(value):
    return isinstance(value, str) and PLACEHOLDER_RE.search(value) is not None


def validate_no_placeholders(value, path, errors):
    if has_placeholder(value):
        errors.append(f"{path} contains placeholder value: {value}")
        return
    if isinstance(value, dict):
        for key, child in value.items():
            validate_no_placeholders(child, f"{path}.{key}", errors)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            validate_no_placeholders(child, f"{path}[{index}]", errors)


def resolve_repo_path(path_text):
    path = Path(path_text)
    if path.is_absolute():
        return path
    return REPO_ROOT / path


def validate_paths(values, field_name, errors):
    for path_text in values or []:
        if not isinstance(path_text, str) or not path_text:
            errors.append(f"{field_name} contains an empty or non-string path")
            continue
        if "://" in path_text:
            continue
        if not resolve_repo_path(path_text).exists():
            errors.append(f"{field_name} path does not exist: {path_text}")


def validate_required_fields(manifest, errors):
    for key in REQUIRED_TOP_LEVEL:
        if key not in manifest:
            errors.append(f"missing top-level field: {key}")

    final_status = manifest.get("final_status")
    if final_status not in FINAL_STATUSES:
        errors.append(f"final_status must be one of {sorted(FINAL_STATUSES)}")

    product = manifest.get("product", {})
    if isinstance(product, dict):
        for field in ["scenario", "target"]:
            if not is_non_empty(product.get(field)):
                errors.append(f"product.{field} is required")

    architecture = manifest.get("architecture", {})
    if isinstance(architecture, dict):
        if not is_non_empty(architecture.get("platform_project")):
            errors.append("architecture.platform_project is required")

    ux = manifest.get("ux", {})
    if isinstance(ux, dict):
        if not is_non_empty(ux.get("entry_point")):
            errors.append("ux.entry_point is required")


def validate_result_closure(result, field_name, final_status, errors):
    if result not in RESULT_STATUSES:
        errors.append(f"{field_name} must be one of {sorted(RESULT_STATUSES)}")
        return
    if result in {"FAIL", "BLOCKED"} and final_status != "BLOCKED":
        errors.append(f"{field_name}={result} requires final_status=BLOCKED")
    if result == "SKIPPED" and final_status == "PASS":
        errors.append(f"{field_name}=SKIPPED cannot use final_status=PASS; use PASS WITH RISKS or BLOCKED")


def required_roles_for_manifest(manifest):
    required_roles = list(BASE_ROLES)
    if manifest.get("reference", {}).get("required"):
        required_roles.append("reference")
    if manifest.get("release", {}).get("required"):
        required_roles.append("release")
    return required_roles


def validate_role_results(manifest, errors):
    role_results = manifest.get("role_results", {})
    if not isinstance(role_results, dict):
        errors.append("role_results must be an object")
        return

    for role in required_roles_for_manifest(manifest):
        if role not in role_results:
            errors.append(f"role_results missing required role: {role}")
            continue
        status = role_results[role].get("status") if isinstance(role_results[role], dict) else None
        if status not in ROLE_STATUSES:
            errors.append(f"role_results.{role}.status must be one of {sorted(ROLE_STATUSES)}")
            continue
        if not role_results[role].get("evidence"):
            errors.append(f"role_results.{role}.evidence is required")
        if status == "WAIVED" and not role_results[role].get("waiver_reason"):
            errors.append(f"role_results.{role}.waiver_reason is required when status is WAIVED")
        if status in {"FAIL", "BLOCKED"} and manifest.get("final_status") != "BLOCKED":
            errors.append(f"role_results.{role}.status={status} requires final_status=BLOCKED")


def validate_role_artifacts(manifest, errors):
    role_artifacts = manifest.get("role_artifacts", {})
    if not isinstance(role_artifacts, dict):
        errors.append("role_artifacts must be an object")
        return

    role_results = manifest.get("role_results", {})
    seen_agent_ids = {}
    for role in required_roles_for_manifest(manifest):
        role_status = role_results.get(role, {}).get("status") if isinstance(role_results, dict) else None
        if role_status == "WAIVED":
            continue
        artifact = role_artifacts.get(role)
        if not isinstance(artifact, dict):
            errors.append(f"role_artifacts.{role} is required for non-waived role")
            continue

        agent_id = artifact.get("agent_id")
        if not is_non_empty(agent_id):
            errors.append(f"role_artifacts.{role}.agent_id is required")
        elif str(agent_id).lower() in LEAD_AGENT_IDS:
            errors.append(f"role_artifacts.{role}.agent_id={agent_id} cannot be the Lead Agent")
        else:
            normalized_agent_id = str(agent_id).lower()
            if normalized_agent_id in seen_agent_ids:
                errors.append(
                    f"role_artifacts.{role}.agent_id duplicates role_artifacts.{seen_agent_ids[normalized_agent_id]}.agent_id"
                )
            else:
                seen_agent_ids[normalized_agent_id] = role

        if not is_non_empty(artifact.get("summary")):
            errors.append(f"role_artifacts.{role}.summary is required")

        validate_role_dispatch(role, artifact.get("dispatch"), manifest.get("final_status"), errors)

        output = artifact.get("output")
        if not isinstance(output, dict):
            errors.append(f"role_artifacts.{role}.output must be an object")
            continue
        for field in ROLE_ARTIFACT_REQUIRED_OUTPUT.get(role, []):
            if not is_non_empty(output.get(field)):
                errors.append(f"role_artifacts.{role}.output.{field} is required")


def validate_role_dispatch(role, dispatch, final_status, errors):
    field_name = f"role_artifacts.{role}.dispatch"
    if not isinstance(dispatch, dict):
        errors.append(f"{field_name} is required")
        return

    mode = dispatch.get("mode")
    if mode not in DISPATCH_MODES:
        errors.append(f"{field_name}.mode must be one of {sorted(DISPATCH_MODES)}")
    for field in ["prompt", "artifact"]:
        if not is_non_empty(dispatch.get(field)):
            errors.append(f"{field_name}.{field} is required")

    if final_status != "BLOCKED":
        if mode == "pending":
            errors.append(f"{field_name}.mode=pending requires final_status=BLOCKED")
        if mode != "codex-subagent":
            errors.append(f"{field_name}.mode={mode} cannot pass final acceptance; use codex-subagent")
        if not is_non_empty(dispatch.get("evidence")):
            errors.append(f"{field_name}.evidence is required when final_status is not BLOCKED")
        if not is_non_empty(dispatch.get("run_id")):
            errors.append(f"{field_name}.run_id is required when final_status is not BLOCKED")
        for field in ["prompt_sha256", "artifact_sha256"]:
            value = dispatch.get(field)
            if not is_non_empty(value):
                errors.append(f"{field_name}.{field} is required when final_status is not BLOCKED")
            elif not isinstance(value, str) or not SHA256_RE.fullmatch(value):
                errors.append(f"{field_name}.{field} must be a lowercase sha256 hex digest")


def validate_testing(manifest, errors):
    testing = manifest.get("testing", {})
    if not isinstance(testing, dict):
        errors.append("testing must be an object")
        return

    commands = testing.get("commands", [])
    if not commands:
        errors.append("testing.commands must include at least one command")
    for index, command in enumerate(commands):
        if not isinstance(command, dict):
            errors.append(f"testing.commands[{index}] must be an object")
            continue
        if not command.get("command"):
            errors.append(f"testing.commands[{index}].command is required")
        result = command.get("result")
        validate_result_closure(
            result,
            f"testing.commands[{index}].result",
            manifest.get("final_status"),
            errors,
        )
        if result == "SKIPPED" and not command.get("reason"):
            errors.append(f"testing.commands[{index}].reason is required when result is SKIPPED")

    for field in ["reference_contract_result", "parity_checklist_result", "build_result"]:
        validate_result_closure(
            testing.get(field),
            f"testing.{field}",
            manifest.get("final_status"),
            errors,
        )

    skipped_checks = testing.get("skipped_checks", []) + manifest.get("release", {}).get("skipped_checks", [])
    for index, skipped in enumerate(skipped_checks):
        if not isinstance(skipped, dict) or not skipped.get("reason"):
            errors.append(f"skipped_checks[{index}].reason is required")
    if manifest.get("final_status") == "PASS" and skipped_checks:
        errors.append("final_status=PASS cannot include skipped checks; use PASS WITH RISKS or BLOCKED")

    if manifest.get("reference", {}).get("required") and manifest.get("final_status") != "BLOCKED":
        for field in ["reference_contract_result", "parity_checklist_result"]:
            if testing.get(field) != "PASS":
                errors.append(f"reference-required work needs testing.{field}=PASS")


def validate_reference(manifest, errors):
    reference = manifest.get("reference", {})
    if not isinstance(reference, dict):
        errors.append("reference must be an object")
        return

    required = bool(reference.get("required"))
    testing = manifest.get("testing", {})
    final_status = manifest.get("final_status")

    if required:
        source_case = reference.get("source_case")
        if not is_non_empty(source_case):
            errors.append("reference.source_case is required when reference.required=true")
        elif "://" not in source_case and not resolve_repo_path(source_case).exists():
            errors.append(f"reference.source_case path does not exist: {source_case}")

    pairs = [
        ("contract_result", "reference_contract_result"),
        ("parity_checklist_result", "parity_checklist_result"),
    ]
    for reference_field, testing_field in pairs:
        reference_result = reference.get(reference_field)
        testing_result = testing.get(testing_field)
        validate_result_closure(reference_result, f"reference.{reference_field}", final_status, errors)
        if reference_result != testing_result:
            errors.append(
                f"reference.{reference_field}={reference_result} must match testing.{testing_field}={testing_result}"
            )
        if required and final_status != "BLOCKED" and reference_result != "PASS":
            errors.append(f"reference-required work needs reference.{reference_field}=PASS")


def validate_review(manifest, errors):
    review = manifest.get("review", {})
    if not isinstance(review, dict):
        errors.append("review must be an object")
        return
    validate_result_closure(review.get("result"), "review.result", manifest.get("final_status"), errors)


def validate_release(manifest, errors):
    release = manifest.get("release", {})
    if not isinstance(release, dict):
        errors.append("release must be an object")
        return

    for index, check in enumerate(release.get("checks", [])):
        if not isinstance(check, dict):
            errors.append(f"release.checks[{index}] must be an object")
            continue
        if not check.get("name"):
            errors.append(f"release.checks[{index}].name is required")
        result = check.get("result")
        validate_result_closure(result, f"release.checks[{index}].result", manifest.get("final_status"), errors)
        if result == "PASS" and not check.get("evidence"):
            errors.append(f"release.checks[{index}].evidence is required when result is PASS")
        if result == "SKIPPED" and not check.get("reason"):
            errors.append(f"release.checks[{index}].reason is required when result is SKIPPED")

    if release.get("required") and not release.get("checks"):
        errors.append("release.checks must include at least one check when release.required=true")


def validate_implementation(manifest, errors):
    implementation = manifest.get("implementation", {})
    if not isinstance(implementation, dict):
        errors.append("implementation must be an object")
        return

    validate_paths(implementation.get("files_changed", []), "implementation.files_changed", errors)
    validate_paths(implementation.get("skills_docs_used", []), "implementation.skills_docs_used", errors)

    testing = manifest.get("testing", {})
    for index, update in enumerate(implementation.get("matrix_updates", [])):
        if not isinstance(update, dict):
            errors.append(f"implementation.matrix_updates[{index}] must be an object")
            continue
        new_status = update.get("to")
        if new_status not in MATRIX_STATUSES:
            errors.append(f"implementation.matrix_updates[{index}].to must be one of {sorted(MATRIX_STATUSES)}")
        if not update.get("evidence"):
            errors.append(f"implementation.matrix_updates[{index}].evidence is required")
        if new_status == "DONE":
            if manifest.get("final_status") != "PASS":
                errors.append(
                    f"implementation.matrix_updates[{index}].to=DONE requires final_status=PASS"
                )
            skipped_checks = testing.get("skipped_checks", []) + manifest.get("release", {}).get("skipped_checks", [])
            if skipped_checks:
                errors.append(f"implementation.matrix_updates[{index}].to=DONE cannot include skipped checks")
            required = {
                "reference_contract_result": testing.get("reference_contract_result"),
                "parity_checklist_result": testing.get("parity_checklist_result"),
                "build_result": testing.get("build_result"),
            }
            for field, result in required.items():
                if result != "PASS":
                    errors.append(f"DONE matrix update requires testing.{field}=PASS, got {result}")


def validate_knowledge_updates(manifest, errors):
    updates = manifest.get("knowledge_updates", [])
    for index, update in enumerate(updates):
        if not isinstance(update, dict):
            errors.append(f"knowledge_updates[{index}] must be an object")
            continue
        for field in KNOWLEDGE_UPDATE_FIELDS:
            if not is_non_empty(update.get(field)):
                errors.append(f"knowledge_updates[{index}].{field} is required")

    if updates and not any(
        is_durable_knowledge_path(path)
        for path in manifest.get("implementation", {}).get("files_changed", [])
    ):
        errors.append("knowledge_updates require at least one durable knowledge doc or skill in implementation.files_changed")


def is_durable_knowledge_path(path_text):
    if not isinstance(path_text, str):
        return False
    normalized = normalize_manifest_path(path_text)
    return (
        normalized in DURABLE_KNOWLEDGE_PATHS
        or normalized.endswith("/ARCHITECTURE.md")
        or normalized.startswith(".agent/skills/")
        or "/.agent/skills/" in normalized
    )


def normalize_manifest_path(path_text):
    path = Path(path_text)
    if path.is_absolute():
        try:
            return path.resolve().relative_to(REPO_ROOT).as_posix()
        except ValueError:
            return path.as_posix()
    normalized = path_text.replace("\\", "/")
    if normalized.startswith("./"):
        return normalized[2:]
    return normalized


def validate_manifest(manifest):
    errors = []
    if not isinstance(manifest, dict):
        return ["manifest must be a JSON object"]

    validate_no_placeholders(manifest, "manifest", errors)
    validate_required_fields(manifest, errors)
    validate_role_results(manifest, errors)
    validate_role_artifacts(manifest, errors)
    validate_reference(manifest, errors)
    validate_review(manifest, errors)
    validate_release(manifest, errors)
    validate_testing(manifest, errors)
    validate_implementation(manifest, errors)
    validate_knowledge_updates(manifest, errors)
    return errors


def main(argv):
    if len(argv) != 2:
        print("usage: validate_acceptance_manifest.py <manifest.json>", file=sys.stderr)
        return 2

    manifest_path = Path(argv[1])
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except OSError as exc:
        print(f"failed to read manifest: {exc}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as exc:
        print(f"invalid JSON: {exc}", file=sys.stderr)
        return 2

    errors = validate_manifest(manifest)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("Acceptance manifest valid")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
