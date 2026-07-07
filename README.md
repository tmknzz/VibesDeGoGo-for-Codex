# VibesDeGoGo! for Codex

A state-and-hook workflow for Codex. It keeps the agent moving through requirements, investigation, implementation, verification, and commit, but stops it before unchecked assumptions, skipped verification, or scope drift.

One asymmetry runs the whole thing:

- Don't stop to ask permission — no "can I continue?", it keeps moving.
- Do stop before a constraint violation — a new dependency, touching auth / persistence / billing / security, a destructive op, or drifting out of the agreed scope: it halts and asks first.

The rules are enforced by hooks (`PreToolUse` / `PostToolUse` / `Stop`) plus a state file, not by prompt text, and a task gate cross-checks the actual file changes against the allowlist you declared. The hooks are a guardrail, not a sandbox: Codex documents them as a guardrail rather than a complete enforcement boundary, so treat this as strong rails plus an audit trail, not proof of correctness.

bash + jq. No account, keys, or telemetry. MIT.

## Core Flow

1. Agree on Goal / Constraints / Acceptance criteria.
2. Write `tasks/vdgg/{id}/requirements.md`.
3. Investigate the codebase and write `investigation.md`.
4. Create `todo.md` and `progress.md`.
5. Implement one bounded task at a time.
6. Verify with concrete checks.
7. Run a focused simplification/review pass.
8. Update progress and ask for validation when needed.
9. Commit, and for the default `branch-pr` workflow, create a PR and stop.
   (A PR is GitHub's confirmation page for a proposed change: nothing lands
   on the main code until you approve the merge.)

## Layout

```text
.agents/skills/vibesdegogo/
  SKILL.md
  scripts/
    vdgg-state.sh
    vdgg-hook-pretool.sh
    vdgg-hook-posttool.sh
    vdgg-hook-stop.sh
    vdgg-hook-userprompt.sh
  references/
    codex-setup.md
.codex/hooks.json
tests/
```

## Install

For local authoring, Codex reads repo skills from `.agents/skills` in this
repository.

For cross-repository use, install the skill in a user-level skill directory:

```bash
mkdir -p "$HOME/.agents/skills"
cp -R .agents/skills/vibesdegogo "$HOME/.agents/skills/vibesdegogo"
```

Then register global hooks in `~/.codex/hooks.json` or `~/.codex/config.toml`.
The global `UserPromptSubmit` hook makes VDGG the default for coding work in
any git repository. The tool hooks enforce the workflow after VDGG state is
initialized in that repository root.
See:

```text
.agents/skills/vibesdegogo/references/codex-setup.md
```

Project-local hooks are included in `.codex/hooks.json`. In Codex, use `/hooks`
to review and trust them.

`jq` is required because the hook scripts parse Codex hook JSON:

```bash
brew install jq               # macOS
sudo apt-get install jq       # Debian / Ubuntu / WSL
apk add jq                    # Alpine
sudo dnf install jq           # Fedora / RHEL
```

## Uninstall

The complete footprint, so you (or your agent) can remove everything:

- Delete `~/.agents/skills/vibesdegogo/`.
- Remove the four hook entries (`PreToolUse`, `PostToolUse`, `Stop`,
  `UserPromptSubmit`) that reference `vdgg-hook-*.sh` from `~/.codex/hooks.json`.
- Per-repository session artifacts: `.codex/.vdgg-*` and `tasks/vdgg/` are
  safe to delete. `.gitignore` gains an auto-appended block for `.codex/.vdgg-*`;
  drop it if you like.
- Keep `.vdgg-target` — it is your configuration file, not something VDGG installed.

## Test

```bash
bash tests/run-all.sh
```

## Optional: MAGI

If you also install **MAGI** (a small open-source 3-persona deliberation skill), VibesDeGoGo! uses it at two points — and silently skips it if you don't: **Step 0** to deliberate a genuinely split, high-stakes decision (it hands back material; you still decide), and **Step 7** as the review gate for subjective artifacts (docs, copy, design). MAGI judges desirability, not code correctness. → https://github.com/tmknzz/MAGI

## Status

This repository is the Codex-focused edition. The Claude Code edition lives separately at [VibesDeGoGo-for-Claude-Code](https://github.com/tmknzz/VibesDeGoGo-for-Claude-Code).