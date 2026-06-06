# VibesDeGoGo! for Codex

VibesDeGoGo! for Codex is a state-and-hook workflow for Codex coding sessions.
It keeps the agent moving through requirements, investigation, planning,
implementation, verification, review, and commit, while stopping before
constraint violations.

## Core Flow

1. Agree on Goal / Constraints / Acceptance criteria.
2. Write `tasks/vdgg/{id}/requirements.md`.
3. Investigate the codebase and write `investigation.md`.
4. Create `todo.md` and `progress.md`.
5. Implement one bounded task at a time.
6. Verify with concrete checks.
7. Run a focused simplification/review pass.
8. Update progress and ask for validation when needed.
9. Commit and create a PR for the default `branch-pr` workflow.

## Layout

```text
.agents/skills/vibesdegogo/
  SKILL.md
  scripts/
    vdgg-state.sh
    vdgg-hook-pretool.sh
    vdgg-hook-posttool.sh
    vdgg-hook-stop.sh
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

## Test

```bash
bash tests/run-all.sh
```

## Status

This repository is the Codex-focused edition. The Claude Code edition lives
separately as `VibesDeGoGo-for-Claude-Code`.
