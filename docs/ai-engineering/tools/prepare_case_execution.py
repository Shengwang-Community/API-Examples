#!/usr/bin/env python3
"""Prepare one cross-platform API Examples requirement package."""

import argparse
import json
import re
import sys
from pathlib import Path

from generate_case_backlog import DEFAULT_MATRIX, REPO_ROOT, generate_execution_units


PLATFORMS = ["android", "ios", "macos", "windows"]
SDK_VERSION_SOURCES = {
    "android": [
        ("Android/APIExample/gradle.properties", r"(?m)^\s*rtc_sdk_version\s*=\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$"),
        ("Android/APIExample-Audio/gradle.properties", r"(?m)^\s*rtc_sdk_version\s*=\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$"),
        ("Android/APIExample-Compose/gradle.properties", r"(?m)^\s*rtc_sdk_version\s*=\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$"),
    ],
    "ios": [
        ("iOS/APIExample/Podfile", r"pod\s+'Shengwang(?:RtcEngine|Audio)_iOS',\s*'([0-9]+\.[0-9]+\.[0-9]+)'"),
        ("iOS/APIExample-Audio/Podfile", r"pod\s+'Shengwang(?:RtcEngine|Audio)_iOS',\s*'([0-9]+\.[0-9]+\.[0-9]+)'"),
        ("iOS/APIExample-OC/Podfile", r"pod\s+'Shengwang(?:RtcEngine|Audio)_iOS',\s*'([0-9]+\.[0-9]+\.[0-9]+)'"),
        ("iOS/APIExample-SwiftUI/Podfile", r"pod\s+'Shengwang(?:RtcEngine|Audio)_iOS',\s*'([0-9]+\.[0-9]+\.[0-9]+)'"),
    ],
    "macos": [
        ("macOS/Podfile", r"pod\s+'ShengwangRtcEngine_macOS',\s*'([0-9]+\.[0-9]+\.[0-9]+)'"),
    ],
    "windows": [
        ("windows/APIExample/install.ps1", r"Shengwang_Native_SDK_for_Windows_v([0-9]+\.[0-9]+\.[0-9]+)_FULL\.zip"),
    ],
}
DEFAULT_PLATFORM_TARGETS = {
    "android": "Android/APIExample/",
    "ios": "iOS/APIExample/",
    "macos": "macOS/",
    "windows": "windows/",
}
PLATFORM_UNIT_GROUPS = {
    "Android full": "android",
    "Android audio": "android",
    "Android Compose": "android",
    "iOS UIKit": "ios",
    "iOS SwiftUI": "ios",
    "iOS Objective-C": "ios",
    "iOS audio": "ios",
    "macOS": "macos",
    "Windows": "windows",
}
ROLE_CONTRACTS = {
    "contract": [
        "shared scenario, APIs, and non-goals",
        "cross-platform behavior contract",
        "target project and allowed files for every platform",
        "reference contract when required",
    ],
    "implementation": [
        "target project",
        "query-cases and upsert-case results",
        "changed files",
        "matrix update proposals",
    ],
    "verification": [
        "findings-first review and parity result",
        "entry point and UX consistency",
        "exact target command strings and command kinds for JSONL evidence binding",
        "target build commands and result",
        "skipped checks with reasons",
    ],
}


def select_execution_unit(units, feature=None, index=0):
    filtered = [unit for unit in units if feature is None or unit["feature"] == feature]
    if not filtered:
        suffix = f" for feature={feature}" if feature else ""
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


def pending_dispatch(name):
    return {
        "mode": "pending",
        "prompt": f"role-prompts/{name}.md",
        "artifact": f"role-artifacts/{name}.json",
    }


def pending_artifact(name, summary, output):
    return {
        "agent_id": f"{name}-agent-pending",
        "dispatch": pending_dispatch(name),
        "status": "BLOCKED",
        "evidence": f"Pending {name} gate.",
        "summary": summary,
        "output": output,
    }


def default_platform_targets():
    return {
        platform: {
            "required": True,
            "target_project": target,
            "key_constraints": [
                f"Use the {platform} project rules and keep source changes inside {target}"
            ],
            "files_allowed": [target],
            "waiver_reason": "",
        }
        for platform, target in DEFAULT_PLATFORM_TARGETS.items()
    }


def collect_sdk_version_checks(target_sdk_version, repo_root=REPO_ROOT, sources=None):
    checks = []
    for platform, entries in (sources or SDK_VERSION_SOURCES).items():
        actual_versions = {}
        problems = []
        for path_text, pattern in entries:
            path = Path(repo_root) / path_text
            if not path.exists():
                actual_versions[path_text] = ""
                problems.append(f"missing {path_text}")
                continue
            matches = sorted(set(re.findall(pattern, path.read_text(encoding="utf-8"))))
            if len(matches) != 1:
                actual_versions[path_text] = ""
                problems.append(f"expected one SDK version in {path_text}, found {len(matches)}")
                continue
            actual_versions[path_text] = matches[0]
            if matches[0] != target_sdk_version:
                problems.append(f"{path_text}={matches[0]}")
        result = "PASS" if not problems else "BLOCKED"
        checks.append(
            {
                "name": f"sdk-version-{platform}",
                "result": result,
                "expected_version": target_sdk_version,
                "actual_versions": actual_versions,
                "evidence": (
                    "; ".join(f"{path}={version}" for path, version in actual_versions.items())
                    if actual_versions
                    else ""
                ),
                "reason": "" if not problems else f"Expected {target_sdk_version}; " + "; ".join(problems),
            }
        )
    return checks


def build_qa_acceptance_seed():
    return {
        "ci_job_url": "",
        "ci_build_number": "",
        "artifacts": {platform: "" for platform in PLATFORMS},
        "result": "BLOCKED",
        "owner": "",
        "evidence": "",
    }


def build_manifest_seed(requirement, source_case):
    reference_required = bool(source_case)
    reference_result = "BLOCKED" if reference_required else "SKIPPED"
    targets = default_platform_targets()
    contract = pending_artifact(
        "contract",
        "Pending shared product, architecture, and reference contract.",
        {
            "scenario": f"Implement {requirement['feature']} consistently across official platforms.",
            "key_apis": requirement["key_apis"],
            "non_goals": [],
            "reference": {
                "required": reference_required,
                "source_case": source_case,
                "contract_result": reference_result,
            },
            "cross_platform_requirements": [],
            "platform_targets": targets,
        },
    )
    platforms = {}
    for platform, target in DEFAULT_PLATFORM_TARGETS.items():
        platforms[platform] = {
            "implementation": pending_artifact(
                f"{platform}-implementation",
                f"Pending {platform} implementation.",
                {
                    "target_project": target,
                    "query_cases": "Pending target project case query.",
                    "upsert_case": "Pending target project update.",
                    "files_changed": [],
                    "matrix_updates": [],
                },
            ),
            "verification": pending_artifact(
                f"{platform}-verification",
                f"Pending independent {platform} verification.",
                {
                    "result": "BLOCKED",
                    "findings": [],
                    "parity_result": reference_result,
                    "entry_point": f"Pending {platform} entry point verification.",
                    "ux_notes": "Pending verification.",
                    "commands": [],
                    "build_result": "BLOCKED",
                    "skipped_checks": [],
                },
            ),
        }
    return {
        "version": 4,
        "final_status": "BLOCKED",
        "requirement": requirement,
        "contract": contract,
        "platforms": platforms,
        "cross_platform_acceptance": {
            "result": "BLOCKED",
            "evidence": "Pending required platform verification.",
            "differences": [],
        },
        "release": {
            "required": True,
            "target_sdk_version": requirement["target_sdk_version"],
            "checks": collect_sdk_version_checks(requirement["target_sdk_version"]),
            "qa_acceptance": build_qa_acceptance_seed(),
            "skipped_checks": [],
        },
        "knowledge_updates": [],
    }


def build_platform_units(units, feature):
    result = {
        platform: {
            "target_project": DEFAULT_PLATFORM_TARGETS[platform],
            "matrix_candidates": [],
        }
        for platform in PLATFORMS
    }
    for unit in units:
        if unit["feature"] != feature:
            continue
        platform = PLATFORM_UNIT_GROUPS.get(unit["platform_unit"])
        if platform:
            result[platform]["matrix_candidates"].append(unit)
    return result


def prepare_case_execution(
    matrix_path,
    feature=None,
    index=0,
    sdk_family=None,
    key_apis=None,
    target_sdk_version=None,
):
    if not target_sdk_version:
        raise ValueError("target_sdk_version is required")
    backlog = generate_execution_units(matrix_path)
    matching = [
        unit for unit in backlog["execution_units"] if feature is None or unit["feature"] == feature
    ]
    selected = select_execution_unit(matching, None, index) if matching else None
    if selected is None and not (feature and sdk_family and key_apis):
        raise ValueError(
            "a requirement outside the actionable matrix needs feature, sdk_family, and key_apis"
        )
    requirement = {
        "feature": feature or selected["feature"],
        "sdk_family": sdk_family or selected["sdk_family"],
        "key_apis": key_apis or selected["key_apis"],
        "target_sdk_version": target_sdk_version,
    }
    source_candidate = None
    if selected and selected["reference_candidates"]:
        source_candidate = selected["reference_candidates"][0]
    source_case = resolve_source_case(source_candidate)
    blockers = []
    if not source_case:
        blockers.append("No DONE reference candidate found; Contract must identify a source case.")
    return {
        "requirement": requirement,
        "platform_units": build_platform_units(backlog["execution_units"], requirement["feature"]),
        "reference_contract": {
            "required": bool(source_case),
            "source_candidate": source_candidate,
            "source_case": source_case,
        },
        "role_contracts": ROLE_CONTRACTS,
        "execution_steps": [
            "Run one shared Contract for all official platforms.",
            "Run Android, iOS, macOS, and Windows Implementation agents independently with attributed deltas.",
            "Run independent platform Verification agents in parallel.",
            "Record cross-platform differences and final acceptance.",
            "Validate the manifest before applying matrix updates.",
        ],
        "acceptance_manifest_seed": build_manifest_seed(requirement, source_case),
        "validation_command": "python3 docs/ai-engineering/tools/validate_acceptance_manifest.py <manifest.json>",
        "blockers": blockers,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--matrix", default=str(DEFAULT_MATRIX))
    parser.add_argument("--feature", help="Requirement feature; defaults to the highest-priority gap")
    parser.add_argument("--sdk-family", help="Required when the feature is not actionable in the matrix")
    parser.add_argument("--key-api", action="append", help="Key SDK API; repeat for multiple APIs")
    parser.add_argument("--target-sdk-version", required=True)
    parser.add_argument("--index", type=int, default=0)
    parser.add_argument("--output")
    args = parser.parse_args(argv)
    try:
        package = prepare_case_execution(
            Path(args.matrix),
            args.feature,
            index=args.index,
            sdk_family=args.sdk_family,
            key_apis=args.key_api,
            target_sdk_version=args.target_sdk_version,
        )
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    payload = json.dumps(package, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        Path(args.output).write_text(payload, encoding="utf-8")
    else:
        print(payload, end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
