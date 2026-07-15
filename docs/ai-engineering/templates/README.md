# AI Engineering Templates

This directory stores reusable templates for repository-level AI engineering workflows.

Templates are not completed evidence. Before using a template, replace every placeholder with live repository data, current command output, and current external evidence.

Templates may intentionally fail validation until their placeholders are replaced. The version 4 manifest stores one shared Contract and one Implementation/Verification pair for each official platform; use the orchestrator to add model, run, host, prompt/artifact, input-snapshot, working-directory, repository-delta, and hashed command-log provenance. Release templates also require the target SDK version, CI artifacts, and QA acceptance evidence.

Do not commit routine execution output from these templates unless the user explicitly asks for a repository evidence snapshot or the run is selected as a representative workflow validation example.

## Templates

| Template | Purpose |
| --- | --- |
| `acceptance-manifest-template.json` | Requirement-level Contract, four platform delivery units, cross-platform acceptance, release, and knowledge evidence. |
| `release-dry-run-template.md` | Human-readable release dry-run evidence snapshot. |
