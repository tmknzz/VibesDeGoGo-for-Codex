# Changelog

## [Unreleased]

## [0.4.0] - 2026-07-08

### Added

- Step 0 consultation mode (wall-bounce) for ambiguous goals, subjective deliverables, high-risk changes, or multiple valid approaches, with an escalation trigger into MAGI when it is installed; Step 7 notes MAGI can also serve as review for subjective deliverables.
- Step 0 now integrates GrillMe, a question-driven pre-filter (`GRILLME=on/off/auto` in `.vdgg-target`; `auto` matches the consultation trigger conditions, off when GrillMe isn't installed) that runs before MAGI.
- Step 7 now requires at least one falsifying verification check (boundary/error/regression) and scales the check count to the change surface instead of capping at three.
- REVIEW_COMMAND guidance now recommends a security perspective for publicly shipped code, with an updated example; simplify explicitly does not cover security.
- `VDGG_REQUIRED=on` entry gate in `.vdgg-target`: even before a session is armed, the pretool hook denies `apply_patch`/`Edit`/`Write` and write-side Bash (redirects, `tee`, `rm/mv/cp/dd/install/truncate/touch/ln/patch/mkfifo/apply_patch`, `sed`/`perl -i`) and `git commit`, and denies writes to `.vdgg-target` itself; fails closed if `jq` is missing while the gate is on.
- Step 8 followup sweep: Step 7 now classifies findings by severity (high/medium/low), low-only findings are deferred to `followup.md` instead of blocking `verified`, Step 5 can pick up `TF`-prefixed followup tasks, and Step 8 builds a followup-sweep queue from `followup.md` after all tasks complete (Step 9 reports any remainder).
- Step reporting: an Agent Role section requires each Step to declare itself at the start, `STEP_REPORT=quiet` in `.vdgg-target` silences it, and delegated sub-agents/executors emit a `[VibesDeGoGo! Delegate] step=N, executor=..., role=...` line.
- Retry-investigation gate: on `reflection` -> `implementing`, a fresh `investigation-r{loop}.md` and `progress.md` (newer than the state file) are now required, backed by a new `_vdgg_mtime` helper.
- `.gitignore` added, tracking `.codex/.vdgg-*` and `tasks/vdgg/`.

### Changed

- VDGG state and tool hooks now resolve the git root before reading or writing `.codex/.vdgg-*`, so sessions started from subdirectories apply to the whole repository.
- Operational tuning ported from the Claude Code edition: `set -o pipefail` guidance (with a false-positive warning) for Step 7's `bash -lc` pipe example, a lighter Step 6-R path for review/simplify-triggered retries, a companion-test note for Step 5 allowlists when signatures change, and stop-hook wording that background waits are a legitimate stop reason.
- README.md Core Flow Step 9 wording aligned with README.ja.md ("Commit, and for the default branch-pr workflow, create a PR and stop.").

### Fixed

- `vdgg_task_begin` now checks the step transition before running side effects (allowlist generation, baseline snapshot), fixing a bug where re-arming outside Step 5 could report success ("began") even though the state write failed afterward.
- The posttool hook now safely handles `tool_response` when Codex 0.139.0 passes it as a string instead of an object, fixing a case where the Bash success/error-ack gate silently stopped working; `codex-setup.md` documents this and the fact that `codex exec` does not fire hooks.
- `_vdgg_mtime` hardened against a GNU/Linux bug where a BSD-style `stat` flag silently succeeded with non-numeric output instead of failing, so the fallback never ran and the reflection gate blocked unconditionally on Linux (the root cause of the Ubuntu CI failures); output is now validated as numeric before falling back to GNU `stat` and then `0`, and the regression test's mtime generation was made POSIX-portable.

### Security

- `.vdgg-target` sourcing replaced with safe key extraction and an allow-list, closing an RCE path (P0-1).
- `.vdgg-target` is now write-protected, closing a gate-forgery path via a self-authored `REVIEW_COMMAND` (P0-2).
- Sidecar guard rewritten with shell-segment splitting and a read-only whitelist (fail-closed).
- `vdgg_state_write` now validates `phase` against a known list of 11 phases so an unknown phase can no longer wipe all gates; the pretool hook's `verified`/`progress`/`commit` arm is consolidated, closing an edit-permission gap in the `verified` phase, and defaults to deny for unrecognized phases.
- `testing` can no longer skip `reflection` to jump straight to `implementing`, and `reflection` can no longer jump straight to `verified`.
- The pretool hook now blocks direct `commit`/`push` to the base branch during the `commit` phase (reading `WORKFLOW`/`BASE_BRANCH` safely), enforcing the branch-pr workflow.

## [0.3.0] - 2026-06-12

### Added

- Initial Codex-only split from VibesDeGoGo!.
- Codex skill, hook scripts, project-local hook config, and smoke tests.
- Global `UserPromptSubmit` hook that makes VDGG the default workflow for coding work in any git repository.
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
