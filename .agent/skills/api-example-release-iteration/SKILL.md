---
name: api-example-release-iteration
description: Use when turning API Examples product requirements into repository changes, adding or modifying sample cases, coordinating platform/project selection, AI agent review, testing gates, or release-iteration acceptance in this repository
---

# API Example Release Iteration

Use this skill as the Lead Agent workflow for API Examples version iteration. It coordinates product scope, repository knowledge, project-level case skills, review roles, and acceptance gates.

## Required Inputs

Before editing, identify:

- Product scenario and key SDK APIs.
- Target platform/project, or ask if missing.
- New case, existing case modification, docs-only, or CI/build workflow change.
- Verification budget: static check, build, device test, or CI.
- Reference platform/project when the request is parity, porting, or gap-filling work.

If the request spans multiple platforms, split the work by platform/project and finish one acceptance unit at a time.

## Source Route

Read in this order:

1. Root `AGENTS.md`.
2. `docs/ai-engineering/knowledge-index.md`.
3. `docs/ai-engineering/release-iteration-gate.md`.
4. `docs/ai-engineering/release-known-issues.md` when release branches, SDK version bumps, CI, signing, packaging, third-party assets, or Android Extension cases are in scope.
5. Target platform `AGENTS.md`.
6. Target project `AGENTS.md`, when present.
7. Target project `ARCHITECTURE.md`.
8. Target project `.agent/skills/query-cases/SKILL.md`, when present and case discovery is needed.
9. Target project `.agent/skills/upsert-case/SKILL.md`, before implementation.
10. Target project `.agent/skills/review-case/SKILL.md`, before final review.

Do not skip project-level skills because they encode platform-specific traps that root docs intentionally do not duplicate.

## Agent Roles

Run these roles in order as separate agents. The Lead Agent coordinates scope and final assembly, but must not self-approve or simulate the Product, Architect, Implementation, Review, Test, or UX roles.

| Role | Pass Condition |
| --- | --- |
| Product Agent | Scenario, target user flow, key APIs, reference contract when required, and non-goals are explicit. |
| Architect Agent | Platform/project choice and red lines are confirmed. |
| Implementation Agent | Diff follows the target `upsert-case` or docs workflow. |
| Review Agent | Findings-first review has no blocking reference-parity, lifecycle, threading, registration, or doc-consistency issues. |
| Test Agent | Appropriate verification was run or blockers are recorded. |
| UX Agent | Case entry, labels, inputs, and layout follow adjacent examples. |

Use `docs/ai-engineering/release-iteration-gate.md` as the detailed checklist for each role.

Each role must produce explicit `role_results` evidence and a structured `role_artifacts` entry with a unique `agent_id`, Codex subagent dispatch provenance, summary, and role-specific output. The same `agent_id` cannot be reused across non-waived roles, and the Lead Agent cannot be recorded as the role owner. If separate Codex subagent execution is unavailable, a role artifact still has `dispatch.mode=pending`, or an accepted role artifact is not `dispatch.mode=codex-subagent`, final status must stay `BLOCKED` unless the user explicitly waives the role separation requirement. Any role can block final acceptance with `FAIL` or `BLOCKED`; a waived role needs a concrete waiver reason.

## Implementation Flow

1. Confirm scope and target project.
2. Query existing cases by feature/API before creating a new one.
3. If parity is required, extract the reference contract from the source implementation, layout/storyboard, strings/arrays, and registration.
4. Select the nearest existing case only for framework patterns such as lifecycle, permissions, UI scaffolding, or registration.
5. Follow the target project's `upsert-case` skill.
6. Keep changes limited to the selected project unless parity or CI work was requested.
7. Update `ARCHITECTURE.md` if the case inventory, path, or key API mapping changes.
8. Run `review-case` plus a reference-to-implementation parity checklist.
9. Run the smallest meaningful verification.
10. Produce an acceptance manifest from `docs/ai-engineering/templates/acceptance-manifest-template.json`.
11. Validate it with `python3 docs/ai-engineering/tools/validate_acceptance_manifest.py <manifest.json>`.
12. Produce the acceptance summary from `release-iteration-gate.md`.

## Case Backlog Execution

For case-backfill orchestration:

1. Start from `docs/ai-engineering/case-maintenance-matrix.md`.
2. Initialize an execution workspace:

   ```bash
   python3 docs/ai-engineering/tools/orchestrate_case_execution.py init \
     --matrix docs/ai-engineering/case-maintenance-matrix.md \
     --run-dir /tmp/api-example-case-run
   ```

3. Add `--feature` and `--platform-unit` only when the user or release scope requires a specific unit; otherwise the tool selects the highest-priority unit.
4. Dispatch the generated `role-prompts/*.md` to separate Codex subagents. The repository tool creates prompts and artifact templates, but it does not spawn agents by itself.
5. Each role agent must write its completed JSON to `role-artifacts/<role>.json`, including `dispatch.mode=codex-subagent`, the subagent `run_id`, prompt/artifact paths, and dispatch evidence. The assemble step adds `prompt_sha256` and `artifact_sha256`.
6. Identify the source reference case and target project before implementation.
7. The Implementation Agent, not the orchestrator script, follows the target project `query-cases`, `upsert-case`, and `review-case` skills and makes any platform source changes.
8. After role agents finish, assemble the run:

   ```bash
   python3 docs/ai-engineering/tools/orchestrate_case_execution.py assemble \
     --run-dir /tmp/api-example-case-run \
     --matrix docs/ai-engineering/case-maintenance-matrix.md \
     --final-status "<PASS|PASS WITH RISKS|BLOCKED>"
   ```

9. Use the generated `final-acceptance-manifest.json` as the acceptance record. The assemble step validates the manifest and applies matrix updates only after the manifest is valid and final status is not `BLOCKED`.
10. Keep runtime-dependent work as `PARTIAL(...)` when device or CI smoke is still pending.

Use `prepare_case_execution.py` or `generate_case_backlog.py` directly only when inspecting or debugging the execution package or backlog order.

## Non-Negotiable Red Lines

- Do not mix platform roots or share source files across platforms.
- Do not add video APIs to audio-only projects.
- Do not hardcode real App IDs, certificates, tokens, or private URLs.
- Do not approve missing leave-channel before destroy/release.
- Do not approve direct UI updates from SDK callbacks on background threads.
- Do not add a new case without registration and discoverability.
- Do not accept a parity change that only matches API names but not the reference case's controls, defaults, enum/option types, limits, and runtime success signals.
- Do not claim full acceptance when required build, device, or CI checks were skipped.
- Do not update a case matrix cell to `DONE` unless final status is `PASS`, there are no skipped checks, and reference contract, parity checklist, and build evidence all pass. `PASS WITH RISKS` can only support a non-final matrix state such as `PARTIAL(...)`.
- Do not claim final acceptance until `validate_acceptance_manifest.py` passes or its blocker is recorded.
- Do not describe this workflow as fully autonomous case generation. The current repository tools prepare and validate the workspace; a human/Lead Agent or future end-to-end orchestrator still has to dispatch role agents and perform the platform implementation step.
- Do not approve release packaging without checking known release risks when the change touches SDK versions, CI, signing, packaging, third-party assets, or Android Extension cases.

## Verification Selection

Use the smallest check that covers the changed surface:

- Docs or skill only: path validation, Markdown sanity, and entrypoint discoverability.
- Android: project Gradle compile/test; device test only when runtime behavior requires it.
- iOS/macOS: pod/workspace readiness plus selected Xcode build when host tools and dependencies are available.
- Windows: MSBuild or Visual Studio project validation when available.
- CI/build scripts: syntax check and targeted dry run when possible.
- Release packaging: apply `docs/ai-engineering/release-known-issues.md` and record SDK version, signing, build-machine, license, and platform-script checks.

Record skipped checks with concrete reasons, not generic "not run".

## Pilot Run Artifacts

Do not write every execution result into `docs/ai-engineering/pilot-runs/`.

Routine acceptance summaries belong in the agent response, PR comment, CI artifact, or task tracker. A repository pilot-run document is only appropriate when it is a curated workflow validation example, such as the first dry run for a new gate, a representative cross-platform rehearsal, or an explicitly requested evidence snapshot.

Use `docs/ai-engineering/templates/release-dry-run-template.md` as the starting point for release dry-run evidence snapshots. Do not commit a filled report unless it meets the curated pilot-run criteria above.

When adding a pilot-run document:

- Use a dated filename.
- Keep it immutable after review; create a new file for a new run instead of rewriting history.
- Mark the observed branch, commit, commands, skipped checks, and final status.
- Do not treat old pilot-run results as current repository state.

## Final Output

End with the acceptance summary template from `docs/ai-engineering/release-iteration-gate.md`. Include:

- Product interpretation.
- Target platform/project.
- Files changed.
- Skills/docs used.
- Review result.
- Test commands and results.
- Role artifact agent IDs.
- Reference contract and parity checklist results when applicable.
- Acceptance manifest validation result.
- UX notes.
- Final status: `PASS`, `PASS WITH RISKS`, or `BLOCKED`.
