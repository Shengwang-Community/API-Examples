#!/usr/bin/env python3
"""Orchestrate one API Examples case execution workspace."""

import argparse
import hashlib
import json
import sys
from copy import deepcopy
from pathlib import Path

from generate_case_backlog import NON_PLATFORM_COLUMNS, parse_status, split_markdown_row
from prepare_case_execution import prepare_case_execution
from validate_acceptance_manifest import validate_manifest


ROLE_ORDER = ["product", "architecture", "reference", "implementation", "review", "test", "ux", "release"]


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def init_workspace(args):
    run_dir = Path(args.run_dir)
    run_dir.mkdir(parents=True, exist_ok=True)

    package = prepare_case_execution(Path(args.matrix), args.feature, args.platform_unit, args.index)
    package["matrix_path"] = str(args.matrix)
    write_json(run_dir / "execution-package.json", package)
    write_json(run_dir / "acceptance-manifest.json", package["acceptance_manifest_seed"])

    artifact_dir = run_dir / "role-artifacts"
    prompt_dir = run_dir / "role-prompts"
    for contract in package["role_contracts"]:
        role = contract["role"]
        artifact = package["acceptance_manifest_seed"]["role_artifacts"][role]
        artifact_payload = {
            "role": role,
            "agent_id": artifact["agent_id"],
            "dispatch": artifact["dispatch"],
            "status": package["acceptance_manifest_seed"]["role_results"][role]["status"],
            "evidence": package["acceptance_manifest_seed"]["role_results"][role]["evidence"],
            "summary": artifact["summary"],
            "output": artifact["output"],
        }
        write_json(artifact_dir / f"{role}.json", artifact_payload)
        write_prompt(prompt_dir / f"{role}.md", role, contract, package)

    if package["reference_contract"]["required"]:
        artifact = package["acceptance_manifest_seed"]["role_artifacts"]["reference"]
        reference_payload = {
            "role": "reference",
            "agent_id": artifact["agent_id"],
            "dispatch": artifact["dispatch"],
            "status": package["acceptance_manifest_seed"]["role_results"]["reference"]["status"],
            "evidence": package["acceptance_manifest_seed"]["role_results"]["reference"]["evidence"],
            "summary": artifact["summary"],
            "output": artifact["output"],
        }
        write_json(artifact_dir / "reference.json", reference_payload)
        write_prompt(
            prompt_dir / "reference.md",
            "reference",
            {
                "role": "reference",
                "required_output": ["source_case", "contract_result", "parity_checklist_result"],
            },
            package,
        )

    print(f"Execution workspace initialized: {run_dir}")
    return 0


def write_prompt(path, role, contract, package):
    unit = package["execution_unit"]
    required_output = "\n".join(f"- {item}" for item in contract["required_output"])
    body = f"""# {role.title()} Agent Task

Feature: {unit["feature"]}
Platform unit: {unit["platform_unit"]}
Target project: {unit["target_project"]}
Reference source: {package["reference_contract"]["source_case"] or "None"}

Required output:
{required_output}

Write your completed artifact to `role-artifacts/{role}.json` with:

- `role`
- `agent_id`
- `dispatch.mode` set to `codex-subagent`
- `dispatch.run_id` set to the spawned subagent id
- `dispatch.prompt` set to `role-prompts/{role}.md`
- `dispatch.artifact` set to `role-artifacts/{role}.json`
- `dispatch.evidence`
- `status`
- `evidence`
- `summary`
- `output`
"""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8")


def assemble_workspace(args):
    run_dir = Path(args.run_dir)
    manifest = read_json(run_dir / "acceptance-manifest.json")
    artifacts = load_role_artifacts(run_dir / "role-artifacts")
    final_manifest = merge_role_artifacts(manifest, artifacts, args.final_status)

    errors = validate_manifest(final_manifest)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    matrix_updates = final_manifest.get("implementation", {}).get("matrix_updates", [])
    if matrix_updates and final_manifest.get("final_status") != "BLOCKED":
        update_matrix(Path(args.matrix), matrix_updates)

    output_path = run_dir / "final-acceptance-manifest.json"
    write_json(output_path, final_manifest)
    print(f"Acceptance manifest valid: {output_path}")
    return 0


def load_role_artifacts(artifact_dir):
    artifacts = {}
    for artifact_path in sorted(artifact_dir.glob("*.json")):
        artifact = read_json(artifact_path)
        role = artifact.get("role") or artifact_path.stem
        attach_dispatch_hashes(artifact, role, artifact_path, artifact_dir.parent)
        artifacts[role] = artifact
    return artifacts


def attach_dispatch_hashes(artifact, role, artifact_path, run_dir):
    dispatch = artifact.setdefault("dispatch", {})
    dispatch.setdefault("artifact", f"role-artifacts/{role}.json")
    dispatch["artifact_sha256"] = sha256_file(artifact_path)

    prompt_path = run_dir / dispatch.get("prompt", f"role-prompts/{role}.md")
    if prompt_path.exists():
        dispatch["prompt_sha256"] = sha256_file(prompt_path)


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def merge_role_artifacts(seed_manifest, artifacts, final_status):
    manifest = deepcopy(seed_manifest)
    manifest["final_status"] = final_status
    manifest["role_results"] = {}
    manifest["role_artifacts"] = {}

    for role in ROLE_ORDER:
        if role not in artifacts:
            continue
        artifact = artifacts[role]
        manifest["role_results"][role] = {
            "status": artifact["status"],
            "evidence": artifact["evidence"],
        }
        if artifact["status"] == "WAIVED" and artifact.get("waiver_reason"):
            manifest["role_results"][role]["waiver_reason"] = artifact["waiver_reason"]
        manifest["role_artifacts"][role] = {
            "agent_id": artifact["agent_id"],
            "dispatch": artifact["dispatch"],
            "summary": artifact["summary"],
            "output": artifact["output"],
        }

    apply_artifact_outputs(manifest, artifacts)
    return manifest


def apply_artifact_outputs(manifest, artifacts):
    if should_apply_artifact(artifacts, "product"):
        output = artifacts["product"]["output"]
        manifest["product"] = {
            "scenario": output["scenario"],
            "target": output["target"],
            "non_goals": output["non_goals"],
        }

    if should_apply_artifact(artifacts, "architecture"):
        output = artifacts["architecture"]["output"]
        manifest["architecture"] = {
            "platform_project": output["platform_project"],
            "key_constraints": output["key_constraints"],
        }

    if should_apply_artifact(artifacts, "reference"):
        output = artifacts["reference"]["output"]
        manifest["reference"] = {
            "required": True,
            "source_case": output["source_case"],
            "contract_result": output["contract_result"],
            "parity_checklist_result": output["parity_checklist_result"],
        }

    if should_apply_artifact(artifacts, "implementation"):
        output = artifacts["implementation"]["output"]
        manifest["implementation"]["files_changed"] = output["files_changed"]
        manifest["implementation"]["matrix_updates"] = matrix_updates_from_output(output)

    if should_apply_artifact(artifacts, "review"):
        output = artifacts["review"]["output"]
        manifest["review"] = {
            "result": output["result"],
            "findings": output["findings"],
        }

    if should_apply_artifact(artifacts, "test"):
        output = artifacts["test"]["output"]
        manifest["testing"] = {
            "commands": output["commands"],
            "skipped_checks": output.get("skipped_checks", []),
            "reference_contract_result": output["reference_contract_result"],
            "parity_checklist_result": output["parity_checklist_result"],
            "build_result": output["build_result"],
        }

    if should_apply_artifact(artifacts, "ux"):
        output = artifacts["ux"]["output"]
        manifest["ux"] = {
            "entry_point": output["entry_point"],
            "notes": output["notes"],
        }


def should_apply_artifact(artifacts, role):
    artifact = artifacts.get(role)
    if not artifact:
        return False
    agent_id = str(artifact.get("agent_id", ""))
    return not (artifact.get("status") == "BLOCKED" and agent_id.endswith("-agent-pending"))


def matrix_updates_from_output(output):
    matrix_update = output.get("matrix_update")
    if matrix_update in (None, "", []):
        return []
    if not isinstance(matrix_update, dict):
        raise ValueError("implementation.output.matrix_update must be an object or empty for completed artifacts")
    required_fields = ["feature", "platform_unit", "from", "to", "evidence"]
    missing_fields = [field for field in required_fields if field not in matrix_update]
    if missing_fields:
        raise ValueError(f"implementation.output.matrix_update missing field(s): {', '.join(missing_fields)}")
    return [
        {
            "feature": matrix_update["feature"],
            "platform_unit": matrix_update["platform_unit"],
            "from": matrix_update["from"],
            "to": matrix_update["to"],
            "evidence": matrix_update["evidence"],
            **({"to_cell": matrix_update["to_cell"]} if "to_cell" in matrix_update else {}),
        }
    ]


def update_matrix(matrix_path, matrix_updates):
    lines = matrix_path.read_text(encoding="utf-8").splitlines()
    for update in matrix_updates:
        lines = apply_matrix_update(lines, update)
    matrix_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def apply_matrix_update(lines, update):
    for index, line in enumerate(lines):
        if not line.startswith("|"):
            continue
        header = split_markdown_row(line)
        if "Feature" not in header or update["platform_unit"] not in header:
            continue
        feature_index = header.index("Feature")
        platform_index = header.index(update["platform_unit"])
        for row_index in range(index + 2, len(lines)):
            row_line = lines[row_index]
            if not row_line.startswith("|"):
                break
            row = split_markdown_row(row_line)
            if len(row) != len(header) or row[feature_index] != update["feature"]:
                continue
            status, _ = parse_status(row[platform_index])
            if status != update["from"]:
                raise ValueError(
                    f"matrix cell {update['feature']} / {update['platform_unit']} is {status}, expected {update['from']}"
                )
            row[platform_index] = f"`{matrix_to_cell(update)}`"
            lines[row_index] = "| " + " | ".join(row) + " |"
            return lines
    raise ValueError(f"matrix row not found for {update['feature']} / {update['platform_unit']}")


def matrix_to_cell(update):
    if update.get("to_cell"):
        return update["to_cell"]
    if update["to"] == "PARTIAL":
        return f"PARTIAL({update['evidence']})"
    return update["to"]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init", help="Create an execution workspace")
    init_parser.add_argument("--matrix", required=True, help="Path to case-maintenance-matrix.md")
    init_parser.add_argument("--feature", help="Feature to execute; omitted means highest-priority unit")
    init_parser.add_argument("--platform-unit", help="Platform unit to execute; omitted means highest-priority unit")
    init_parser.add_argument("--run-dir", required=True, help="Output execution workspace")
    init_parser.add_argument("--index", type=int, default=0, help="Index within the filtered backlog")

    assemble_parser = subparsers.add_parser("assemble", help="Assemble role artifacts into a validated manifest")
    assemble_parser.add_argument("--run-dir", required=True, help="Execution workspace")
    assemble_parser.add_argument("--matrix", required=True, help="Path to case-maintenance-matrix.md")
    assemble_parser.add_argument("--final-status", default="BLOCKED", help="Final acceptance status")

    args = parser.parse_args(argv)
    try:
        if args.command == "init":
            return init_workspace(args)
        if args.command == "assemble":
            return assemble_workspace(args)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 2


if __name__ == "__main__":
    sys.exit(main())
