#!/bin/bash
set -euo pipefail

INPUT=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  # Allow the current command through if it is itself an attempt to install jq.
  if printf '%s' "$INPUT" | grep -qE '"command"[[:space:]]*:[[:space:]]*"[^"]*(brew[[:space:]]+(install|reinstall)|apt(-get)?[[:space:]]+install|apk[[:space:]]+add|dnf[[:space:]]+install|yum[[:space:]]+install|pacman[[:space:]]+-S)[[:space:]]+[^"]*jq'; then
    exit 0
  fi
  {
    echo "VibesDeGoGo! for Codex: jq is required for hooks but was not found on PATH."
    echo "  macOS:               brew install jq"
    echo "  Debian/Ubuntu/WSL:   sudo apt-get install jq"
    echo "  Alpine:              apk add jq"
    echo "  Fedora/RHEL:         sudo dnf install jq"
  } >&2
  exit 2
fi

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] || CWD=$(pwd)

ACTIVE_FILE="$CWD/.codex/.vdgg-active"
[ -f "$ACTIVE_FILE" ] || exit 0
VDGG_ID=$(cat "$ACTIVE_FILE")
[ -n "$VDGG_ID" ] || exit 0
STATE_FILE="$CWD/.codex/.vdgg-state-${VDGG_ID}"
[ -f "$STATE_FILE" ] || exit 0

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
PHASE=$(grep '^phase=' "$STATE_FILE" | cut -d= -f2 || true)
STEP=$(grep '^step=' "$STATE_FILE" | cut -d= -f2 || true)
LOOP_COUNT=$(grep '^loop_count=' "$STATE_FILE" | cut -d= -f2 || true)
LOOP_COUNT="${LOOP_COUNT:-0}"
TASKS_DIR="$CWD/tasks/vdgg/${VDGG_ID}"

block() {
  echo "VibesDeGoGo! for Codex [${VDGG_ID}]: $1" >&2
  exit 2
}

patch_files() {
  printf '%s\n' "$COMMAND" \
    | sed -nE 's/^\*\*\* (Add|Update|Delete) File: (.*)$/\2/p'
}

changed_files() {
  case "$TOOL_NAME" in
    apply_patch)
      patch_files
      ;;
    Edit|Write)
      printf '%s\n' "$INPUT" | jq -r '.tool_input.file_path // empty'
      ;;
  esac
}

path_is_tasks_file() {
  local p="$1"
  [[ "$p" == "$TASKS_DIR/"* ]] || [[ "$p" == "tasks/vdgg/${VDGG_ID}/"* ]]
}

path_is_state_file() {
  local p="$1"
  [[ "$p" == *"/.codex/.vdgg-state-"* ]] || [[ "$p" == *"/.codex/.vdgg-active" ]] \
    || [[ "$p" == ".codex/.vdgg-state-"* ]] || [[ "$p" == ".codex/.vdgg-active" ]]
}

if [ "$TOOL_NAME" = "Bash" ] && [ -f "$CWD/.codex/.vdgg-error-pending" ]; then
  if ! printf '%s' "$COMMAND" | grep -qF '[Error Acknowledged]'; then
    block "Previous command failed. Acknowledge it with [Error Acknowledged] before running another command."
  fi
  rm -f "$CWD/.codex/.vdgg-error-pending"
fi

if [ "$TOOL_NAME" = "Bash" ] && printf '%s' "$COMMAND" | grep -qE '(\.codex/\.vdgg-state-|\.codex/\.vdgg-active)'; then
  # `git commit` is exempt: the command text may legitimately mention state-file
  # paths inside the commit message. Commit phase rules apply elsewhere.
  if ! printf '%s' "$COMMAND" | grep -qE '(^|[^a-zA-Z0-9_-])git[[:space:]]+commit($|[[:space:]])'; then
    # `>[^&]` excludes fd-merge redirects (2>&1, >&2) which are not destructive.
    if printf '%s' "$COMMAND" | grep -qE '(>[^&]|tee[[:space:]]|sed[[:space:]]+-i|mv[[:space:]]|cp[[:space:]]|rm[[:space:]])'; then
      block "Direct state-file edits are blocked. Use vdgg_state_* helpers."
    fi
  fi
fi

if [ "$TOOL_NAME" = "apply_patch" ] || [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
  while IFS= read -r file_path; do
    [ -n "$file_path" ] || continue
    path_is_state_file "$file_path" && block "Direct state-file edits are blocked. Use vdgg_state_* helpers."
  done < <(changed_files)
fi

if [ "$TOOL_NAME" = "Bash" ] && printf '%s' "$COMMAND" | grep -qE 'vdgg_state_(advance|loop|write)[[:space:]]+[0-9]+'; then
  TARGET_STEP=$(printf '%s' "$COMMAND" | sed -nE 's/.*vdgg_state_(advance|loop|write)[[:space:]]+([0-9]+).*/\2/p' | head -1)
  if [ -n "$TARGET_STEP" ]; then
    if ! printf '%s' "$COMMAND" | grep -qF "[VibesDeGoGo! Step ${TARGET_STEP} Start]" \
      && ! { [ "$TARGET_STEP" = "2" ] && printf '%s' "$COMMAND" | grep -qF '[VibesDeGoGo! Declaration]'; }; then
      block "State transition commands must include the matching VibesDeGoGo! Step declaration."
    fi
  fi
fi

if [ "$TOOL_NAME" = "Bash" ] && [ "$PHASE" = "requirements" ]; then
  if printf '%s' "$COMMAND" | grep -qE 'vdgg_state_(advance|loop|write)[[:space:]]+3[[:space:]]+investigating'; then
    [ -f "$TASKS_DIR/requirements.md" ] || block "requirements.md is required before investigation."
  fi
fi

if [ "$TOOL_NAME" = "Bash" ] && [ "$PHASE" = "implementing" ]; then
  TEST_PATTERN='swift[[:space:]]+test|xcodebuild[[:space:]]+[^|]*[[:space:]]test|pytest|npm[[:space:]]+(run[[:space:]]+)?test|pnpm[[:space:]]+(run[[:space:]]+)?test|yarn[[:space:]]+(run[[:space:]]+)?test|go[[:space:]]+test|cargo[[:space:]]+test|jest|vitest|mocha'
  if [ -f "$CWD/.vdgg-target" ]; then
    EXTRA=$(grep '^TEST_COMMAND_PATTERN=' "$CWD/.vdgg-target" 2>/dev/null | sed -E 's/^[^=]*=//; s/^"(.*)"$/\1/' | head -1)
    [ -z "${EXTRA:-}" ] || TEST_PATTERN="${TEST_PATTERN}|${EXTRA}"
  fi
  if printf '%s' "$COMMAND" | grep -qE "(^|[[:space:];&|(])(${TEST_PATTERN})([[:space:]]|$)"; then
    block "Tests are blocked in implementing. Advance to Step 7 testing first."
  fi
fi

case "$PHASE" in
  declare|requirements|investigating|planning)
    if [ "$TOOL_NAME" = "apply_patch" ] || [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
      while IFS= read -r file_path; do
        [ -n "$file_path" ] || continue
        path_is_tasks_file "$file_path" || block "Only the active tasks/vdgg/${VDGG_ID}/ files may be edited in phase ${PHASE}."
      done < <(changed_files)
    fi
    ;;
  task-selected)
    if [ "$TOOL_NAME" = "apply_patch" ] || [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
      block "Edits are blocked in task-selected. Advance to implementing first."
    fi
    ;;
  implementing|testing)
    if [ "$TOOL_NAME" = "Bash" ] && printf '%s' "$COMMAND" | grep -qE '(^|[^a-zA-Z0-9_-])git[[:space:]]+commit($|[[:space:]])'; then
      block "Commit is blocked before Step 9."
    fi
    if [ "$TOOL_NAME" = "Bash" ] && [ "$PHASE" = "testing" ]; then
      if printf '%s' "$COMMAND" | grep -qE 'vdgg_state_(advance|loop|write)[[:space:]]+[0-9]+[[:space:]]+verified'; then
        REVIEW_FILE="$CWD/.codex/.vdgg-review-sentinel-${VDGG_ID}-${LOOP_COUNT}"
        [ -f "$REVIEW_FILE" ] || block "Run the Codex review gate with vdgg_state_mark_reviewed before verified."
        MODIFIED=$(grep '^modified=' "$REVIEW_FILE" | sed 's/^modified=//' | head -1)
        [ "$MODIFIED" != "1" ] || block "Review changed files. Go through reflection and retest."
        rm -f "$REVIEW_FILE"
      fi
    fi
    ;;
  reflection)
    if [ "$TOOL_NAME" = "apply_patch" ] || [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
      while IFS= read -r file_path; do
        [ -n "$file_path" ] || continue
        case "$file_path" in
          "$TASKS_DIR/progress.md"|tasks/vdgg/"$VDGG_ID"/progress.md|"$TASKS_DIR"/investigation-r*.md|tasks/vdgg/"$VDGG_ID"/investigation-r*.md) ;;
          *) block "Reflection may only edit progress.md and investigation-r*.md." ;;
        esac
      done < <(changed_files)
    fi
    ;;
  progress|commit)
    if [ "$TOOL_NAME" = "apply_patch" ] || [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
      while IFS= read -r file_path; do
        [ -n "$file_path" ] || continue
        path_is_tasks_file "$file_path" && continue
        if [ -f "$CWD/.vdgg-target" ]; then
          if grep -E '^VERSION_FILE_[0-9]+_PATH=' "$CWD/.vdgg-target" | sed -E 's/^[^=]*=//; s/^"(.*)"$/\1/' | grep -qx "$file_path"; then
            continue
          fi
        fi
        block "Only progress and configured version files may be edited in phase ${PHASE}."
      done < <(changed_files)
    fi
    ;;
esac

exit 0

