#!/usr/bin/env python3
"""Prepare the next API Examples case-backfill execution package."""

import argparse
import json
import sys
from pathlib import Path

from generate_case_backlog import DEFAULT_MATRIX, REPO_ROOT, generate_execution_units


ROLE_CONTRACTS = [
    {
        "role": "product",
        "required_output": [
            "observable sample behavior",
            "entry point name",
            "key SDK APIs",
            "reference contract when required",
            "non-goals",
        ],
    },
    {
        "role": "architecture",
        "required_output": [
            "target platform/project",
            "SDK family compatibility",
            "lifecycle and threading constraints",
            "files allowed to change",
        ],
    },
    {
        "role": "implementation",
        "required_output": [
            "query-cases result",
            "upsert-case result",
            "changed files",
            "matrix update proposal",
        ],
    },
    {
        "role": "review",
        "required_output": [
            "findings-first review",
            "reference-to-implementation parity checklist",
            "lifecycle/threading/resource cleanup verdict",
        ],
    },
    {
        "role": "test",
        "required_output": [
            "commands run",
            "reference contract result",
            "parity checklist result",
            "build result",
            "skipped checks with reasons",
        ],
    },
    {
        "role": "ux",
        "required_output": [
            "menu or entry path",
            "display name and input review",
            "layout or interaction notes",
        ],
    },
]


def select_execution_unit(units, feature=None, platform_unit=None, index=0):
    filtered = [
        unit
        for unit in units
        if (feature is None or unit["feature"] == feature)
        and (platform_unit is None or unit["platform_unit"] == platform_unit)
    ]
    if not filtered:
        filters = []
        if feature is not None:
            filters.append(f"feature={feature}")
        if platform_unit is not None:
            filters.append(f"platform_unit={platform_unit}")
        suffix = f" for {', '.join(filters)}" if filters else ""
        raise ValueError(f"no execution units found{suffix}")
    if index < 0 or index >= len(filtered):
        raise ValueError(f"execution unit index {index} is out of range; {len(filtered)} unit(s) available")
    return filtered[index]


def source_case_from_candidate(candidate):
    if not candidate:
        return ""
    return f"{candidate['project'].rstrip('/')}/{candidate['path'].lstrip('/')}"


def resolve_source_case(candidate):
    source_case = source_case_from_candidate(candidate)
    if not source_case:
        return ""

    direct_path = REPO_ROOT / source_case
    if direct_path.exists():
        return source_case

    project_root = REPO_ROOT / candidate["project"]
    basename = Path(candidate["path"].rstrip("/")).name
    if not project_root.exists() or not basename:
        return source_case

    matches = [
        path
        for path in project_root.rglob(basename)
        if "build" not in path.relative_to(project_root).parts
    ]
    if not matches:
        return source_case

    matches.sort(key=lambda path: (len(path.parts), path.as_posix()))
    return matches[0].relative_to(REPO_ROOT).as_posix()


def build_manifest_seed(unit, source_case):
    reference_required = bool(source_case)
    reference_result = "BLOCKED" if reference_required else "SKIPPED"
    scenario = f"Backfill {unit['platform_unit']} {unit['feature']} API example."
    role_results = {
        contract["role"]: {
            "status": "BLOCKED",
            "evidence": f"Pending {contract['role']} gate.",
        }
        for contract in ROLE_CONTRACTS
    }
    if reference_required:
        role_results["reference"] = {
            "status": "BLOCKED",
            "evidence": "Pending reference contract gate.",
        }

    role_artifacts = {
        "product": {
            "agent_id": "product-agent-pending",
            "summary": "Pending Product Agent output.",
            "output": {
                "scenario": scenario,
                "target": unit["target_project"],
                "key_apis": unit["key_apis"],
                "non_goals": ["Pending Product Agent non-goals."],
            },
        },
        "architecture": {
            "agent_id": "architecture-agent-pending",
            "summary": "Pending Architect Agent output.",
            "output": {
                "platform_project": unit["target_project"],
                "key_constraints": [f"SDK family: {unit['sdk_family']}"],
                "files_allowed": [unit["target_project"]],
            },
        },
        "implementation": {
            "agent_id": "implementation-agent-pending",
            "summary": "Pending Implementation Agent output.",
            "output": {
                "query_cases": "Pending target project query-cases skill.",
                "upsert_case": "Pending target project upsert-case skill.",
                "files_changed": ["Pending implementation."],
                "matrix_update": f"{unit['platform_unit']} {unit['feature']} remains pending.",
            },
        },
        "review": {
            "agent_id": "review-agent-pending",
            "summary": "Pending Review Agent output.",
            "output": {
                "result": "BLOCKED",
                "findings": ["Pending review."],
                "parity_checklist": "Pending reference-to-implementation parity review.",
            },
        },
        "test": {
            "agent_id": "test-agent-pending",
            "summary": "Pending Test Agent output.",
            "output": {
                "commands": ["Run the target project minimum verification from AGENTS.md"],
                "reference_contract_result": reference_result,
                "parity_checklist_result": reference_result,
                "build_result": "BLOCKED",
            },
        },
        "ux": {
            "agent_id": "ux-agent-pending",
            "summary": "Pending UX Agent output.",
            "output": {
                "entry_point": "Pending target project registration",
                "notes": "Pending UX review.",
            },
        },
    }
    if reference_required:
        role_artifacts["reference"] = {
            "agent_id": "reference-agent-pending",
            "summary": "Pending Reference Agent output.",
            "output": {
                "source_case": source_case,
                "contract_result": reference_result,
                "parity_checklist_result": reference_result,
            },
        }

    for role, artifact in role_artifacts.items():
        artifact["dispatch"] = pending_dispatch(role)

    return {
        "version": 1,
        "final_status": "BLOCKED",
        "product": {
            "scenario": scenario,
            "target": unit["target_project"],
            "non_goals": [],
        },
        "reference": {
            "required": reference_required,
            "source_case": source_case,
            "contract_result": reference_result,
            "parity_checklist_result": reference_result,
        },
        "architecture": {
            "platform_project": unit["target_project"],
            "key_constraints": [f"SDK family: {unit['sdk_family']}"],
        },
        "implementation": {
            "files_changed": [],
            "skills_docs_used": [".agent/skills/api-example-release-iteration/SKILL.md"],
            "matrix_updates": [],
        },
        "review": {
            "result": "BLOCKED",
            "findings": [],
        },
        "testing": {
            "commands": [
                {
                    "command": "Run the target project minimum verification from AGENTS.md",
                    "result": "BLOCKED",
                }
            ],
            "skipped_checks": [],
            "reference_contract_result": reference_result,
            "parity_checklist_result": reference_result,
            "build_result": "BLOCKED",
        },
        "release": {
            "required": False,
            "checks": [],
            "skipped_checks": [],
        },
        "ux": {
            "entry_point": "Pending target project registration",
            "notes": "",
        },
        "knowledge_updates": [],
        "role_results": role_results,
        "role_artifacts": role_artifacts,
    }


def pending_dispatch(role):
    return {
        "mode": "pending",
        "prompt": f"role-prompts/{role}.md",
        "artifact": f"role-artifacts/{role}.json",
    }


def build_execution_package(unit):
    source_candidate = unit["reference_candidates"][0] if unit["reference_candidates"] else None
    source_case = resolve_source_case(source_candidate)
    blockers = []
    if not source_case:
        blockers.append("No DONE reference candidate found in the matrix; identify a source contract before implementation.")

    return {
        "execution_unit": unit,
        "reference_contract": {
            "required": bool(source_case),
            "source_candidate": source_candidate,
            "source_case": source_case,
        },
        "role_contracts": ROLE_CONTRACTS,
        "execution_steps": [
            "Read root AGENTS.md and docs/ai-engineering knowledge sources.",
            "Read target platform/project AGENTS.md and ARCHITECTURE.md.",
            "Extract the reference contract before implementation.",
            "Run target project query-cases skill.",
            "Run target project upsert-case skill.",
            "Run target project review-case skill and reference parity checklist.",
            "Run the smallest meaningful verification and record skipped checks with reasons.",
            "Fill and validate the acceptance manifest before changing the matrix status.",
        ],
        "acceptance_manifest_seed": build_manifest_seed(unit, source_case),
        "validation_command": "python3 docs/ai-engineering/tools/validate_acceptance_manifest.py <manifest.json>",
        "blockers": blockers,
    }


def prepare_case_execution(matrix_path, feature=None, platform_unit=None, index=0):
    backlog = generate_execution_units(matrix_path)
    unit = select_execution_unit(backlog["execution_units"], feature, platform_unit, index)
    return build_execution_package(unit)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--matrix", default=str(DEFAULT_MATRIX), help="Path to case-maintenance-matrix.md")
    parser.add_argument("--feature", help="Select a specific feature from the backlog")
    parser.add_argument("--platform-unit", help="Select a specific platform unit from the backlog")
    parser.add_argument("--index", type=int, default=0, help="Index within the filtered backlog")
    args = parser.parse_args(argv)

    try:
        package = prepare_case_execution(Path(args.matrix), args.feature, args.platform_unit, args.index)
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(json.dumps(package, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
