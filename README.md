# VibesDeGoGo! for Codex

**Keep Codex's momentum. Drop the wreckage.**

Codex is fast, and it loves to cross the finish line. That's exactly the danger: it races to "done" on assumptions it never checked, verification it skipped, and scope it quietly drifted past — then hands you a green checkmark over a mess.

VibesDeGoGo! for Codex keeps that drive and lays down rails. It is a state-and-hook workflow that keeps Codex's momentum while stopping the three things that turn a fast finish into a costly one: **unchecked assumptions, skipped verification, and scope drift.**

One asymmetry runs the whole thing:

- **Don't stop to ask permission** — no "can I continue?", it keeps moving.
- **Do stop before a constraint violation** — a new dependency, touching auth / persistence / billing / security, a destructive op, or drifting out of the agreed scope: it halts and asks first.

The rules are not a polite request in a prompt — they are enforced by hooks (`PreToolUse` / `PostToolUse` / `Stop`) plus a state file, and a task gate cross-checks the actual file changes against the allowlist you declared. (Honest caveat, kept from day one: Codex documents its hooks as a guardrail, not a complete enforcement boundary — so treat this as strong rails plus an audit trail, not a proof of correctness.)

Just bash + jq. No SaaS, no account, no API key, no telemetry. MIT, and free.

> Where this comes from: I don't write code — I have never written or read a line of it. The tools in this repo are real, tested, and open source anyway, because the rails do the reading I can't: every step verified, tests must pass, nothing ships unreviewed. That's the point — VibesDeGoGo! is how someone who can't code keeps a fast agent honest.

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

## Test

```bash
bash tests/run-all.sh
```

## Optional: MAGI

If you also install **MAGI** (a small open-source 3-persona deliberation skill), VibesDeGoGo! uses it at two points — and silently skips it if you don't: **Step 0** to deliberate a genuinely split, high-stakes decision (it hands back material; you still decide), and **Step 7** as the review gate for subjective artifacts (docs, copy, design). MAGI judges desirability, not code correctness. → https://github.com/tmknzz/MAGI

## Status

This repository is the Codex-focused edition. The Claude Code edition lives separately at [VibesDeGoGo-for-Claude-Code](https://github.com/tmknzz/VibesDeGoGo-for-Claude-Code).

## Support

It's free, and it stays free. If it ever saves you a weekend, a coffee is welcome — never expected.
