# API Examples Release Iteration Gate

This gate defines how AI-generated API Example changes are accepted. Each agent role has a narrow responsibility and must produce evidence before the iteration is considered complete.

## Gate Overview

| Role | Responsibility | Required Evidence |
| --- | --- | --- |
| Lead Agent | Own scope, routing, and final acceptance | Target platform/project, changed files, final status |
| Product Agent | Convert request into concrete sample behavior | Feature/API list, user-visible behavior, reference contract when parity is required, explicit non-goals |
| Architect Agent | Protect repository and platform boundaries | Selected project, SDK type, lifecycle and registration constraints |
| Implementation Agent | Add or modify the case using project rules | Diff limited to expected files, docs updated when needed |
| Review Agent | Check lifecycle, threading, permissions, cleanup, and conventions | `review-case` findings or equivalent checklist |
| Test Agent | Run the smallest meaningful verification | Commands, results, skipped checks with reasons |
| UX Agent | Check sample discoverability and interaction consistency | Menu/display name, entry flow, strings, layout notes |

The Lead Agent must not mark the iteration accepted until every role is either passed or explicitly waived by the user.

Each role result must include evidence and a structured role artifact. Product, Architect, Implementation, Review, Test, and UX must be executed by separate Codex subagents with distinct `agent_id` values and subagent dispatch provenance before final acceptance. The Lead Agent cannot be recorded as the owner of any role artifact. If separate subagent execution is unavailable, final status must remain `BLOCKED` unless the user explicitly waives the role separation requirement. Any role with `FAIL` or `BLOCKED` forces final status `BLOCKED`; any `WAIVED` role requires a waiver reason.

Every non-waived role artifact must include:

- `agent_id`: the independent role agent identity.
- `dispatch`: execution mode, subagent run id, prompt path, prompt sha256, artifact path, artifact sha256, and evidence for the independent role run. `dispatch.mode=pending` is allowed only while final status is `BLOCKED`; accepted work requires `dispatch.mode=codex-subagent`.
- `summary`: concise role conclusion.
- `output`: structured role-specific fields used by the acceptance manifest validator.

## Phase 1: Intake Gate

The iteration can start only after these items are known:

- Platform or project target.
- SDK family: full RTC SDK, voice/audio SDK, or platform-specific variant.
- New case vs existing case modification.
- Feature name and key SDK APIs to demonstrate.
- Expected user flow in the sample.
- Whether parity is required across other projects.
- Verification budget: static check, build, device test, or CI.

If the platform is not named and the request is not clearly single-platform, ask for scope before editing.

## Phase 2: Knowledge Gate

Before implementation, the Lead Agent must gather these sources:

- Root `AGENTS.md`.
- Target platform `AGENTS.md`.
- Target project `AGENTS.md`, if present.
- Target project `ARCHITECTURE.md`.
- Target project `query-cases` skill, if present.
- Target project `upsert-case` skill.
- Target project `review-case` skill.

If any expected source is missing, continue with the closest local equivalent and record the gap in the final acceptance summary.

## Phase 3: Product Gate

The Product Agent passes only when the request is represented as:

- One-sentence scenario.
- User-visible entry point name.
- Key SDK APIs demonstrated.
- Inputs the user must provide, such as channel name, role, token, or media file.
- Expected success signal in the UI or logs.
- Non-goals for this iteration.

Reject the gate if the request is still phrased only as "support API X" without observable sample behavior.

## Phase 3.5: Reference Contract Gate

Use this gate whenever the work ports, mirrors, or fills parity against an existing platform/project case.

The Lead Agent must extract a reference contract before implementation:

- Reference files read: implementation source, layout or storyboard, string/array resources, and registration entry.
- User-visible controls, default selections, limits, and disabled/enabled states.
- SDK APIs, overloads, enum or option types, default values, and call order.
- State transitions and callback behavior that affect the sample flow.
- Expected observable success signals, such as stats, resolution, role state, logs, or UI changes.

The contract must separate framework patterns from product behavior. Nearby cases may be used for lifecycle, permissions, UI scaffolding, or registration style, but product semantics must come from the reference case.

Reject the gate if the implementation only matches API names or compiles but has not been checked against the reference contract.

## Phase 4: Architecture Gate

The Architect Agent passes only when these statements are true:

- The selected project matches the SDK family and UI framework.
- No files outside the selected platform or project are required, unless parity or shared CI work was requested.
- The case follows the project's registration mechanism.
- The case owns engine creation, channel leave, and destroy/release.
- UI updates from SDK callbacks are dispatched to the platform main thread.
- Sensitive configuration remains placeholder-based or locally ignored.

Reject the gate for any cross-platform sharing shortcut, audio/video SDK mismatch, or lifecycle ownership ambiguity.

## Phase 5: Implementation Gate

The Implementation Agent passes only when:

- Existing case search was performed first.
- The target project's `upsert-case` skill was followed.
- New files use project naming and directory conventions.
- Registration and localization are complete for the selected project.
- `ARCHITECTURE.md` is updated if the case inventory or API mapping changed.
- The diff contains no unrelated formatting churn.

For docs-only or workflow-only changes, this gate requires that the new docs are discoverable from `AGENTS.md` or another existing entrypoint.

## Phase 6: Review Gate

The Review Agent must inspect the final diff and report findings first. Review dimensions:

- Reference-contract parity for user-visible controls, SDK overloads, enum/option types, defaults, and limits.
- Engine lifecycle and teardown order.
- Callback thread safety.
- Permission flow before join or device access.
- SDK API call order.
- Error and token-expiration handling where applicable.
- Resource cleanup for media players, screen capture, audio mixing, custom sources, timers, observers, and delegates.
- Project code style and registration consistency.

Use the target project's `review-case` skill when available. If the change is docs-only, review for broken links, stale file paths, ambiguous instructions, and contradiction with existing `AGENTS.md`.

For parity work, the Review Agent must include a reference-to-implementation checklist. A build pass is not enough to pass review if any product behavior from the reference case is missing or replaced by a similar-but-different sample behavior.

## Phase 7: Test Gate

The Test Agent picks the smallest check that proves the changed surface:

| Change Type | Minimum Check |
| --- | --- |
| Documentation or skill only | Static file/path validation and basic Markdown sanity |
| Android source change | Project Gradle compile or test from project `AGENTS.md` |
| Android UI/runtime behavior | `connectedAndroidTest` or manual device smoke when required |
| iOS source change | Pod install status plus Xcode build for selected workspace/scheme |
| macOS source change | Pod install status plus Xcode build for `APIExample` |
| Windows source change | Visual Studio/MSBuild check when available |
| CI/build script change | Script syntax check plus targeted dry run when possible |

If a check cannot be run because credentials, SDK packages, device access, or host tools are missing, record the blocker and run the strongest available static substitute.

For parity work, record three separate results:

- Reference Contract: PASS, FAIL, or BLOCKED.
- Parity Checklist: PASS, FAIL, or BLOCKED.
- Build Result: PASS, FAIL, or BLOCKED.

Do not mark the iteration accepted when any test command, reference contract, parity checklist, or build result is `FAIL` or `BLOCKED`; those results force final status `BLOCKED`. `SKIPPED` checks are not compatible with final status `PASS`; use `PASS WITH RISKS` only when runtime/device checks are unavailable but the reference contract, parity checklist, and build result all pass.

## Phase 7.5: Release Packaging Gate

Use this gate when the work touches release branches, SDK version bumps, CI, signing, packaging, third-party assets, Android Extension cases, or release automation.

Required checks:

- SDK version files match the intended release SDK across changed platform projects.
- Android Extension `include` files are refreshed when SDK headers are required.
- Jenkins node or build-machine reachability is confirmed for packaging jobs.
- iOS/macOS certificate expiration is inspected or printed before packaging.
- Third-party beauty license expiration is checked when those cases are included in the release.
- Windows packaging scripts are checked for path length and permission issues when Windows release artifacts are in scope.
- API Examples pipeline integration status is confirmed for the target release region.

Use `docs/ai-engineering/release-known-issues.md` for the detailed issue list and automation backlog.

## Phase 8: UX Gate

The UX Agent passes only when:

- The case appears in the expected menu/list/scene tree.
- Display name and description are concise and consistent with adjacent cases.
- Entry screen asks only for necessary inputs.
- Join/leave controls and status feedback follow the selected project's pattern.
- Layout does not hide essential video or control elements.
- Audio-only samples do not show video affordances.

For docs-only workflow changes, the UX gate checks that a future agent can find the workflow from the root entrypoint without guessing.

## Phase 9: Machine Gate

Every implementation or workflow iteration should produce an acceptance manifest based on `docs/ai-engineering/templates/acceptance-manifest-template.json`.

For case-backfill work, use `docs/ai-engineering/tools/orchestrate_case_execution.py init` to create the role-agent workspace and `orchestrate_case_execution.py assemble` to produce the final manifest. The repository tool prepares prompts and assembles artifacts; it does not spawn agents or edit platform source files by itself. Dispatch the prompts through the active agent runtime or thread workflow, and keep platform code changes inside the Implementation Agent following the target project skills. The assemble step validates the manifest before applying matrix updates, and it does not apply matrix updates when final status is `BLOCKED`.

Validate it before final acceptance:

```bash
python3 docs/ai-engineering/tools/validate_acceptance_manifest.py <manifest.json>
```

The validator checks:

- Required top-level sections and final status.
- Role status, role evidence, and waiver reasons.
- Role artifacts, distinct role `agent_id` values, `codex-subagent` dispatch mode, subagent run id, prompt/artifact sha256 provenance for accepted work, and role-specific output fields.
- Placeholder values are removed from filled manifests.
- Review, reference, release, and role results are consistent with final status.
- File and skill/doc paths referenced by the implementation.
- Test command results, build result, skipped-check reasons, and `SKIPPED` checks under final status.
- `DONE` matrix updates are backed by final status `PASS`, reference, parity, build evidence, and no skipped checks. `PASS WITH RISKS` can update a matrix cell only to a non-final state such as `PARTIAL(...)`.
- Knowledge-update records include source, symptom, root cause, guardrail, verification, and update date, and are backed by a durable knowledge document or repository skill change.

Routine manifests are execution artifacts and should not be committed unless the user explicitly requests a repository evidence snapshot or the run is selected as a curated pilot-run example.

## Current Automation Boundary

This workflow is documented and partially automated. The repository tools can select a backlog unit, create a role-agent workspace, validate role artifacts, assemble an acceptance manifest, and apply gated matrix updates. They do not yet perform end-to-end autonomous implementation.

The missing production-grade automation is a separate orchestrator that dispatches real role agents, records run provenance, invokes target project `query-cases`, `upsert-case`, and `review-case` skills, writes platform code, runs verification, fills the final manifest, and updates durable knowledge candidates. Until that exists, do not describe the workflow as "product aligned, then AI automatically generates and accepts the case" without a human/Lead Agent operating the implementation step.

## Final Acceptance Template

Use this format at the end of each iteration:

```markdown
## Acceptance Summary

Product:
- Scenario:
- Target:
- Non-goals:

Reference:
- Source case:
- Contract result:
- Parity checklist result:

Architecture:
- Platform/project:
- Key constraints:

Implementation:
- Files changed:
- Skills/docs used:

Review:
- Result:
- Findings:

Testing:
- Commands:
- Result:
- Skipped checks:

Manifest:
- Path:
- Validation:

Release:
- Required:
- Checks:
- Skipped checks:

UX:
- Entry point:
- Notes:

Final status: PASS | PASS WITH RISKS | BLOCKED
```

`PASS WITH RISKS` is acceptable only when skipped checks are caused by unavailable external dependencies and the remaining static review is clean. `BLOCKED` is required when product scope, platform choice, or build prerequisites are unknown.

`DONE` or accepted status must not be based on compilation alone. For parity work, the Lead Agent needs final status `PASS`, no skipped checks, and evidence from the reference contract, parity checklist, and build result before updating planning artifacts to a completed state.
