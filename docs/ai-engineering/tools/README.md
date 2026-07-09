# AI Engineering Tools

This directory contains lightweight repository-local validation tools for the AI engineering workflow.

## Acceptance Manifest Validator

Use `validate_acceptance_manifest.py` to verify that a filled acceptance manifest has the required role evidence, independent role artifacts, Codex subagent dispatch provenance, test evidence, skipped-check reasons, file paths, matrix status rules, and knowledge-update fields.

```bash
python3 docs/ai-engineering/tools/validate_acceptance_manifest.py <manifest.json>
```

The template manifest intentionally contains placeholders and must not pass validation until filled with live evidence. The validator rejects placeholder values, mismatched reference/test results, failed review, release, or test gates without `final_status=BLOCKED`, `SKIPPED` checks under `final_status=PASS`, missing role evidence, missing role artifacts, accepted role artifacts that are not `dispatch.mode=codex-subagent`, missing subagent `run_id`, missing prompt/artifact sha256 provenance, duplicate role `agent_id` values, Lead-owned role artifacts, and `DONE` matrix updates without final status `PASS`, reference, parity, build evidence, and no skipped checks. When `knowledge_updates` are present, at least one durable knowledge document or repository skill must also be listed in `implementation.files_changed`.

The manifest should usually stay outside the commit as an execution artifact. Commit it only when the user explicitly asks for a repository evidence snapshot or when it is selected as a curated pilot-run example.

Run the validator tests with:

```bash
python3 docs/ai-engineering/tools/validate_acceptance_manifest_test.py
```

## Case Backlog Generator

Use `generate_case_backlog.py` to convert `MISSING` and `PARTIAL` cells in `case-maintenance-matrix.md` into platform execution units.

```bash
python3 docs/ai-engineering/tools/generate_case_backlog.py
```

The output is JSON. Each unit includes priority, severity, target project, key APIs, current matrix status, notes, and `reference_candidates` from `DONE(...)` cells in the same matrix row. Priority comes from the `Confirmed Gaps` table, including known aliases between gap labels and matrix feature names. Use this generator to inspect backlog order; use `orchestrate_case_execution.py` as the normal case-backfill workspace entrypoint.

Run the generator tests with:

```bash
python3 docs/ai-engineering/tools/generate_case_backlog_test.py
```

## Case Execution Preparation

Use `prepare_case_execution.py` as the lower-level helper for selecting the next execution unit and emitting a structured package for the Lead Agent. The package includes the selected backlog unit, resolved reference candidate, role contracts, role artifact seeds, execution steps, and an acceptance-manifest seed that validates as the initial `BLOCKED` state.

```bash
python3 docs/ai-engineering/tools/prepare_case_execution.py
```

By default it selects the highest-priority actionable unit. Use `--feature` and `--platform-unit` to prepare a specific unit:

```bash
python3 docs/ai-engineering/tools/prepare_case_execution.py --feature "Join channel audio" --platform-unit "Windows"
```

This tool does not edit platform source files or spawn agents. It turns the matrix backlog into a machine-readable execution contract that the Lead Agent and role agents must carry through project skills, review, testing, manifest validation, and matrix update.

Run the preparation tests with:

```bash
python3 docs/ai-engineering/tools/prepare_case_execution_test.py
```

## Case Execution Orchestrator

Use `orchestrate_case_execution.py` as the normal case-backfill workspace runner. It creates a run workspace, writes role prompts and role artifact templates, assembles completed role artifacts into a final acceptance manifest, validates that manifest, and applies matrix updates only after validation passes with a non-`BLOCKED` final status. `DONE` matrix updates still require final status `PASS`; `PASS WITH RISKS` is limited to non-final updates such as `PARTIAL(...)`.

This tool does not spawn role agents and does not edit platform source files. The active agent runtime must dispatch `role-prompts/*.md` to separate Codex subagents. Each completed role artifact must replace the default `dispatch.mode=pending` seed with `dispatch.mode=codex-subagent`, the subagent `run_id`, prompt/artifact paths, and dispatch evidence before the final status can be `PASS` or `PASS WITH RISKS`; the assemble step records `prompt_sha256` and `artifact_sha256`. The Implementation Agent is responsible for running the target project `query-cases`, `upsert-case`, and `review-case` skills and making any source changes.

## Current Automation Boundary

These tools are workflow infrastructure, not a full autonomous code-generation product. They prepare and validate the execution workspace, but they do not dispatch subagents, generate platform code, run platform builds automatically, or summarize historical failures into knowledge updates. They can validate recorded subagent run ids and prompt/artifact hashes after separate subagents have run. Full automation still requires a separate end-to-end orchestrator.

Initialize a run:

```bash
python3 docs/ai-engineering/tools/orchestrate_case_execution.py init \
  --matrix docs/ai-engineering/case-maintenance-matrix.md \
  --run-dir /tmp/api-example-case-run
```

By default `init` selects the highest-priority actionable unit. Add `--feature` and `--platform-unit` when the user or release scope requires a specific unit.

After separate role agents finish and write `role-artifacts/*.json`, assemble the run:

```bash
python3 docs/ai-engineering/tools/orchestrate_case_execution.py assemble \
  --run-dir /tmp/api-example-case-run \
  --matrix docs/ai-engineering/case-maintenance-matrix.md \
  --final-status "PASS WITH RISKS"
```

Run the orchestrator tests with:

```bash
python3 docs/ai-engineering/tools/orchestrate_case_execution_test.py
```
