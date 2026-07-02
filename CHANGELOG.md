# Changelog

## [0.3.0] - 2026-06-12

### Added

- `vdgg_review_run`: runs `REVIEW_COMMAND` from the project-root `.vdgg-target` (or an explicit command) and writes the review sentinel only on success.
- `_vdgg_ensure_gitignore`: appends a `.codex/.vdgg-*` ignore block to `.gitignore` (marker-guarded, idempotent).
- SKILL.md docs: `REVIEW_COMMAND` / `STEP3-4-6_EXECUTOR_COMMAND` delegation contract, the `[Error Acknowledged]` gate, and rollback recovery guidance.
- CI: GitHub Actions workflow running syntax checks and the test suite on ubuntu and macos.
- `README.ja.md`: Japanese README.
- Tests: zsh regression suite, 8→5 reset/clear behavior, loop-survival for allowlist/gate/rollback, `vdgg_review_run`, fakebin jq cases, sentinel forgery, posttool Edit/Write sentinel flip.

### Changed

- zsh safety: `local path` renamed throughout (`path` is tied to `$PATH` in zsh and silently emptied it; live bug).
- `vdgg_state_write` optional args 5/6: omit = preserve, `-` = clear.
- 8→5 transition resets the loop counter AND clears task scope (allowlist + baseline), so `vdgg_task_begin` is mechanically required per task. **Behavior change:** task notes under `tasks/vdgg/{id}/` no longer need allowlisting.
- `vdgg_task_begin` performs a single atomic state write (perl/sed removed).
- Allowlist, changed-files, and rollback all resolve from stored state so the task gate survives retry loops.
- Changed-files task-notes exemption scoped to the active session id only.
- Sidecar write-protection generalized to `.codex/.vdgg-*` (sentinel forgery closed).
- posttool hook flips the review sentinel on Edit/Write in addition to apply_patch.
- jq-missing hooks fail open when no VDGG session is active; active sessions keep failing closed with install hints.

## [Unreleased]

### Added

- Step 7 now requires at least one falsifying verification check (boundary/error/regression) and scales the check count to the change surface instead of capping at three.
- REVIEW_COMMAND guidance now recommends a security perspective for publicly shipped code, with an updated example; simplify explicitly does not cover security.
- Initial Codex-only split from VibesDeGoGo!.
- Codex skill, hook scripts, project-local hook config, and smoke tests.
- Global `UserPromptSubmit` hook that makes VDGG the default workflow for
  coding work in any git repository.

### Changed

- VDGG state and tool hooks now resolve the git root before reading or writing
  `.codex/.vdgg-*`, so sessions started from subdirectories apply to the whole
  repository.
