---
name: vibesdegogo
description: "Use VibesDeGoGo! for Codex when the user asks Codex to carry coding work through requirements, investigation, planning, implementation, verification, progress reporting, and commit/PR with safety stops."
version: 0.3.0
---

# VibesDeGoGo! for Codex

VibesDeGoGo! for Codex is a serial, state-file-driven workflow for autonomous coding in Codex. It follows the VibesDeGoGo! for Claude Code step model first; do not simplify the workflow unless the user explicitly asks for a lighter mode.

## When To Use

Use this skill for coding work where the user wants Codex to continue through implementation, verification, and commit/PR.

Trigger phrases include `VibesDeGoGo! for Codex`, `VibesDeGoGo!`, `/VibesDeGoGo!`, and Japanese equivalents such as `VibesDeGoGoで進めて`.

Do not use it for wording-only requests, open-ended discussion, or brainstorming where no repository workflow should execute.

## Important Codex Differences

- State lives in `.codex/.vdgg-active` and `.codex/.vdgg-state-{id}`.
- Task files still live in `tasks/vdgg/{id}/`.
- Prefer global hooks in `~/.codex/hooks.json` or `~/.codex/config.toml` so VDGG rules apply across repositories. Repo-local `.codex/hooks.json` is optional and only covers that repository after trust.
- Hook commands should call the installed skill path, normally `$HOME/.agents/skills/vibesdegogo`, or set `VDGG_CODEX_SKILL_DIR` to an absolute skill directory. Do not assume the target project contains `.agents/skills/vibesdegogo`.
- Codex hook coverage is a guardrail, not a complete enforcement boundary. When unsure, stop before risky work.
- Codex does not have the exact Claude Code `simplify` gate. Use the Codex review gate in this skill instead: after verification, run a focused simplification/review pass yourself, record it with `vdgg_state_mark_reviewed`, then advance to `verified`.
- After a failed Bash command, the next command you issue must contain `[Error Acknowledged]` in its text before anything else runs (the pretool error gate). If the hook blocks you, include that marker in your next command text to clear the gate before continuing.
- Each implementation loop must use a task allowlist and task gate: `vdgg_task_begin` records the allowed files and baseline, `vdgg_task_gate` must pass before `verified`, and `vdgg_task_rollback` reverts the current task when the gate fails.

Use this resolver inside every shell command that calls state helpers:

```bash
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
if [ ! -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ]; then
  VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
fi
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
```

## Step 0: Agree On Requirements

Before starting the state machine, draft and get agreement on:

1. Goal: what state or user value should be achieved.
2. Constraints: what must not change and what boundaries apply.
3. Acceptance criteria: concrete checks that determine completion.

Default constraints must include:

- Prefer the target environment's standard features, components, APIs, and patterns.
- Do not add custom UI, custom components, custom state management, custom design systems, custom utilities, or external dependencies unless the need is clear.
- Stop before changing constraints, adding dependencies, changing API/persistence/auth/permissions/security/billing/analytics/user-data behavior, destructive operations, or broad renames.
- Do not mark work complete without verification.

Start Step 1 only after the user clearly accepts the draft.

Do not create or advance `.codex/.vdgg-*` state files, create task files, switch branches, or edit implementation files before Step 0 is accepted. Step 0 happens before state exists, so hooks cannot fully enforce it; the agent must stop itself here.

## Step 0 Mode: Consultation (壁打ち)

When the requirements cannot yet be safely fixed, run Step 0 as a consultation (壁打ち) before drafting Goal / Constraints / Acceptance. Enter this mode when any of these hold: the goal is ambiguous; the work is subjective or creative — docs, naming, copy, design, a handbook, anything an AI can produce where "good" lives in the user's head, not only in code; the change is high-stakes or hard to reverse (public artifacts, contracts); or more than one defensible direction exists. For a clear, mechanical task with one obvious shape, skip this mode and draft the three items directly.

Consultation is a sounding board. It is none of its three failure modes:

- **Not guess-and-go:** do not silently pick one reading and start building.
- **Not option-dumping:** do not hand over a bare list ("A, B, or C?") and make the user do the thinking.
- **Not autonomous-finalize:** do not settle a subjective or scope question for the user behind a closed door.

Loop until the WHAT is agreed:

1. Name the decisions the result actually hinges on — real forks, not pseudo-choices. Raise a few at a time; do not flood.
2. For each, lay out the trade-offs (what each option wins and loses) and give a recommendation with its reasoning. Recommend; do not merely survey.
3. The user decides or redirects. On every subjective or scope question the user is the decider; the agent supplies the thinking, not the verdict.
4. For a genuinely split, high-stakes fork, escalate that one point to a deeper, multi-perspective deliberation: run the MAGI skill if it is installed; if not, get a second opinion another way (a different model, or a structured review). Bring the output back as material — still for the user to decide.

Do not relitigate a settled point, and do not stall: drive toward convergence. When the WHAT is agreed, leave consultation mode and write `requirements.md`. For subjective artifacts, record in Acceptance what "good" was agreed to mean, so completion stays checkable. Then proceed to Step 1.

## Step 0 Helper: Grill Me (optional)

The Consultation loop above is the baseline for resolving ambiguity. Grill Me is an optional third part — a question-driven interrogator that walks the decision tree one branch at a time — that can be slotted in **before** drafting Goal / Constraints / Acceptance, to pre-filter ambiguity through structured waves of questions, each with a recommended answer.

When Grill Me is engaged, Step 0 runs in three layers before drafting:

1. **Shallow consultation** — the baseline loop above raises real forks and gives recommendations.
2. **Grill Me pass** — sequential question waves drive the user through unresolved branches, each question carrying a recommended answer; the user accepts, redirects, or rejects per question.
3. **MAGI escalation** — for any remaining genuinely split, high-stakes fork, step 4 of the Consultation loop still applies (run MAGI if installed, else get a second opinion another way).

Then drafting `requirements.md` proceeds as usual.

Grill Me is a pre-filter, not a replacement for MAGI. Skipping Grill Me is safe because MAGI remains the deeper-deliberation backstop for high-stakes forks.

Control via `.vdgg-target`:

```bash
# Step 0 Grill Me toggle. Grill Me is an optional question-driven
# interrogator that walks the decision tree one branch at a time and
# runs before drafting Goal / Constraints / Acceptance.
#   off  (default) — do not run Grill Me.
#   on             — always run Grill Me at Step 0.
#   auto           — run when the Consultation entry conditions hold
#                    (ambiguous goal, subjective work, high stakes,
#                    multiple defensible directions).
# Treated as off if the Grill Me skill is not installed.
GRILLME=auto
```

If the Grill Me skill is not installed, the setting is treated as `off` and Step 0 continues with Consultation. The orchestrating agent invokes the installed Grill Me skill directly; there is no shell helper for this (the same convention as MAGI escalation).

## Step 1: Formation

```bash
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
if [ ! -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ]; then
  VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
fi
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_init
```

For the default `branch-pr` workflow, create a feature branch after initialization and before code edits.

Branch name is derived from the Step 0 Goal, not from the VibesDeGoGo! id. Pick a name in the form `{type}/{slug}` where:

- `{type}` is one of `feat`, `fix`, `refactor`, `docs`, `test`, `chore` (same vocabulary as the Step 9 commit type).
- `{slug}` is a short kebab-case summary of the change (3-5 words, lowercase, ASCII, hyphen-separated). Drop articles and filler.
- Examples: `feat/japanese-readme`, `fix/init-portability`, `refactor/state-helpers`.

```bash
WORKFLOW=branch-pr
BASE_BRANCH=""
# Never `source` .vdgg-target: it is a repository-controlled file, and sourcing
# it would execute any code an untrusted repo places there. Read only the needed
# keys and validate them.
if [ -f .vdgg-target ]; then
  WORKFLOW=$(grep -m1 '^WORKFLOW=' .vdgg-target | sed -E 's/^[^=]*=//; s/^"(.*)"$/\1/')
  BASE_BRANCH=$(grep -m1 '^BASE_BRANCH=' .vdgg-target | sed -E 's/^[^=]*=//; s/^"(.*)"$/\1/')
  case "$WORKFLOW" in trunk|branch-pr) ;; *) WORKFLOW=branch-pr ;; esac
  case "$BASE_BRANCH" in ''|*[!A-Za-z0-9._/-]*) BASE_BRANCH="" ;; esac
fi
WORKFLOW=${WORKFLOW:-branch-pr}
if [ "${WORKFLOW:-branch-pr}" != "trunk" ]; then
  if [ -z "${BASE_BRANCH:-}" ]; then
    BASE_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
    BASE_BRANCH=${BASE_BRANCH:-main}
  fi
  # VDGG_BRANCH: agent fills in based on the agreed Step 0 Goal.
  VDGG_BRANCH="<type>/<kebab-case-slug>"
  git checkout -b "$VDGG_BRANCH"
fi
```

Nesting is allowed: if the current branch is already a feature branch, a new `{type}/{slug}` branch is still created on top of it. The Step 1 block runs once per session because `vdgg_state_init` refuses a second initialization.

Then output:

```text
[VibesDeGoGo! Declaration] id=<vdgg_get_id output>
```

## Step 2: Requirements

Write `tasks/vdgg/{id}/requirements.md`:

```markdown
## Goal
...

## Constraints
...

## Acceptance criteria
...
```

Advance:

```bash
# [VibesDeGoGo! Step 2 Start] step=2, phase=requirements, loop=0
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
[ -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ] || VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_advance 2 requirements
```

## Step 3: Investigation

Read actual project files. Do not guess. Trace direct callers and impact. Record unknowns explicitly in `tasks/vdgg/{id}/investigation.md`.

Advance:

```bash
# [VibesDeGoGo! Step 3 Start] step=3, phase=investigating, loop=0
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
[ -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ] || VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_advance 3 investigating
```

## Step 4: Planning

Create `tasks/vdgg/{id}/todo.md` and `tasks/vdgg/{id}/progress.md`.

Advance:

```bash
# [VibesDeGoGo! Step 4 Start] step=4, phase=planning, loop=0
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
[ -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ] || VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_advance 4 planning
```

## Step 5: Select One Task

Choose exactly one task sized for a full implementation cycle:

- one task must be small enough to complete implementation, tests, build, and real/manual check in one Step 6 to Step 8 loop;
- split separate provider/API/auth/key-storage/UI/persistence/versioning risks into separate tasks;
- do not select umbrella tasks such as `T1-T3` or "all model providers";
- if the selected task cannot be verified with the current acceptance criteria in one Step 7, split it before Step 6.
- declare an allowlist of every implementation/test/documentation file this task is allowed to change; keep it narrow and task-specific.

Choose one task and record it:

```bash
# [VibesDeGoGo! Step 5 Start] step=5, phase=task-selected, loop=0
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
[ -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ] || VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_advance 5 task-selected
vdgg_task_begin "T1: title" path/to/file1 path/to/file2
```

The pretool hook blocks implementation edits until `vdgg_task_begin` has created an active allowlist. During Step 6 and Step 7, hook-mediated `apply_patch`, `Edit`, and `Write` edits outside that allowlist are blocked.

## Step 6: Implement

Advance before editing implementation files:

```bash
# [VibesDeGoGo! Step 6 Start] step=6, phase=implementing, loop=0
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
[ -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ] || VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_advance 6 implementing
```

Do not run verification commands in this phase.

## Step 7: Verify And Review

State the verification checks you will run, scaled to the change's surface — roughly 1 to 3 for a small, localized change, more when it spans multiple files or touches a contract; do not stop at three if the surface is larger. At least one must be a check that would FAIL if the change were wrong — a boundary, error, or regression case, not only a happy-path confirmation. Then run them through `vdgg_task_gate`. Pass the verification command as separate shell words, for example `vdgg_task_gate npm test`, or use `vdgg_task_gate bash -lc 'command with pipes'`.

```bash
# [VibesDeGoGo! Step 7 Start] step=7, phase=testing, loop=0
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
[ -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ] || VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_advance 7 testing
vdgg_task_gate <verification-command> [args...]
```

After checks pass, do a focused simplification/review pass:

- remove unnecessary complexity,
- confirm standard-first choices,
- confirm no constraints were violated,
- record the review in `progress.md`.

Then mark the Codex review gate:

```bash
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
[ -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ] || VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_mark_reviewed
```

Alternatively, use `vdgg_review_run` to run a dedicated external review command and mark the gate in one step. It runs `REVIEW_COMMAND` from `.vdgg-target` (or an explicit command) and writes the review sentinel only when the command exits 0; a non-zero exit propagates without writing the sentinel. Prefer a different vendor than the implementing model for the reviewer. The reviewer must be read-only: findings only, no edits. For code that ships to other machines or handles user data, the review prompt must include a security perspective (injection, secrets exposure, unsafe file/network/exec operations) — the simplify gate does not cover security.

```bash
# With an explicit command:
vdgg_review_run codex exec --sandbox read-only 'review the diff; exit 1 on blocking findings'

# Using REVIEW_COMMAND from .vdgg-target (no args):
vdgg_review_run
```

For a **subjective artifact** (docs, copy, naming, design — where quality is a judgment, not something a test can decide), this review pass can be the `MAGI` skill when it is installed: run MAGI as the review and `vdgg_state_mark_reviewed` only when MAGI passes. If MAGI is not installed, do the focused review yourself as above. MAGI judges desirability, not code correctness — correctness still rides on tests and your review.

Relevant `.vdgg-target` keys for Step 7 and step delegation:

```bash
# External review command. Must exit 0 to pass. Use a different vendor.
REVIEW_COMMAND="claude -p 'review the working tree diff for correctness and security (injection, secrets exposure, unsafe file/network/exec operations, data loss); exit non-zero on blocking findings'"

# Optional delegated step executors. When set, run the command for that step
# instead of working inline, then validate the output artifacts (file exists +
# required headings) before advancing.
STEP3_EXECUTOR_COMMAND=""
STEP4_EXECUTOR_COMMAND=""
STEP6_EXECUTOR_COMMAND=""
```

Step 6 delegation stays subject to the task allowlist and `vdgg_task_gate`; out-of-allowlist edits by the executor are caught at the gate.

Finally advance:

```bash
# [VibesDeGoGo! Step 7 Start] step=7, phase=verified, loop=0
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
[ -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ] || VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_advance 7 verified
```

The pretool hook blocks `verified` until both `vdgg_task_gate` and `vdgg_state_mark_reviewed` have succeeded.

If verification fails, run `vdgg_task_rollback`, go to reflection, select exactly one revised hypothesis, and retry. If review changes implementation files, go to reflection and retest. If `vdgg_task_rollback` refuses because files outside the allowlist changed, resolve those manually (`git status` + `git checkout -- <file>`) and rerun it.

## Step 6-R: Reflection

Advance:

```bash
# [VibesDeGoGo! Step 6 Start] step=6, phase=reflection, loop=<same loop>
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
[ -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ] || VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_advance 6 reflection
```

Write `tasks/vdgg/{id}/investigation-r{loop}.md` and update `progress.md` with:

1. Root Cause Investigation.
2. Pattern Analysis.
3. Hypothesis: exactly one hypothesis.
4. Implementation plan: exactly one fix.

Return to implementation:

```bash
# [VibesDeGoGo! Step 6 Start] step=6, phase=implementing, loop=<next loop>
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
[ -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ] || VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_loop 6 implementing
```

If the revised hypothesis needs files outside the current allowlist, do not try to widen the allowlist in place — `vdgg_task_begin` cannot re-arm outside Step 5 (6 -> 5 is not a legal transition) and will fail loudly. Adapt the fix to the current allowlist (e.g. downgrade an optional cleanup to a followup note), or complete/close this task and take the wider scope as a new task via Step 8 -> Step 5.

## Step 8: Progress And Validation Request

Advance:

```bash
# [VibesDeGoGo! Step 8 Start] step=8, phase=progress, loop=0
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
[ -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ] || VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_advance 8 progress
```

Update `progress.md`, update configured version files if `.vdgg-target` requires it, and ask the user for validation when needed.

## Step 9: Commit

Advance:

```bash
# [VibesDeGoGo! Step 9 Start] step=9, phase=commit, loop=0
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
[ -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ] || VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_advance 9 commit
```

Commit format:

```text
{type}: {summary}
```

Default `branch-pr` behavior:

1. commit on the feature branch,
2. push the feature branch,
3. create a PR,
4. report the PR URL,
5. stop for human merge approval.

`trunk` workflow is allowed only when `.vdgg-target` explicitly sets `WORKFLOW=trunk`.

After PR creation or trunk commit/push decision:

```bash
VDGG_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
VDGG_CODEX_SKILL_DIR="${VDGG_CODEX_SKILL_DIR:-$HOME/.agents/skills/vibesdegogo}"
[ -f "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh" ] || VDGG_CODEX_SKILL_DIR="$VDGG_REPO_ROOT/.agents/skills/vibesdegogo"
source "$VDGG_CODEX_SKILL_DIR/scripts/vdgg-state.sh"
vdgg_state_clear
```

## Stop Conditions

Do not stop for progress confirmation. Stop intentionally with `[Intentional Stop]` before:

- violating Step 0 constraints,
- adding or changing dependencies,
- changing API, persistence, auth, permissions, security, billing, analytics, or user-data contracts,
- destructive operations,
- broad renames,
- inability to satisfy or verify acceptance criteria.
- inability to rollback a failed task gate cleanly.
