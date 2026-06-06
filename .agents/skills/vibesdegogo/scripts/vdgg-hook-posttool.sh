#!/bin/bash
set -euo pipefail

INPUT=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  # jq missing: do not block. Pretool surfaces the install hint when a tool call
  # actually requires hook enforcement.
  exit 0
fi

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] || CWD=$(pwd)
if ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null); then
  CWD="$ROOT"
fi
ACTIVE_FILE="$CWD/.codex/.vdgg-active"
[ -f "$ACTIVE_FILE" ] || exit 0
VDGG_ID=$(cat "$ACTIVE_FILE")
[ -n "$VDGG_ID" ] || exit 0
STATE_FILE="$CWD/.codex/.vdgg-state-${VDGG_ID}"
[ -f "$STATE_FILE" ] || exit 0

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
PHASE=$(grep '^phase=' "$STATE_FILE" | cut -d= -f2 || true)
LOOP_COUNT=$(grep '^loop_count=' "$STATE_FILE" | cut -d= -f2 || true)
LOOP_COUNT="${LOOP_COUNT:-0}"

if [ "$TOOL_NAME" = "apply_patch" ] && [ "$PHASE" = "testing" ]; then
  REVIEW_FILE="$CWD/.codex/.vdgg-review-sentinel-${VDGG_ID}-${LOOP_COUNT}"
  if [ -f "$REVIEW_FILE" ]; then
    MODIFIED_FILES=$(printf '%s\n' "$COMMAND" | sed -nE 's/^\*\*\* (Add|Update|Delete) File: (.*)$/\2/p' | paste -sd, -)
    TMP=$(mktemp)
    grep -v '^modified=' "$REVIEW_FILE" | grep -v '^modified_files=' > "$TMP" || true
    {
      echo "modified=1"
      echo "modified_files=${MODIFIED_FILES}"
    } >> "$TMP"
    mv "$TMP" "$REVIEW_FILE"
  fi
fi

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

EXIT_CODE=$(printf '%s' "$INPUT" | jq -r '.tool_response.exit_code // .tool_response.metadata.exit_code // 0')
STDERR_TEXT=$(printf '%s' "$INPUT" | jq -r '.tool_response.stderr // .tool_response.output // empty')
STDOUT_TEXT=$(printf '%s' "$INPUT" | jq -r '.tool_response.stdout // empty')

if printf '%s' "$COMMAND" | grep -qE 'vdgg_state_(init|write|advance|loop|clear|read|mark_reviewed)'; then
  exit 0
fi

IS_SEARCH=0
if printf '%s' "$COMMAND" | grep -qE '(^|[[:space:];&|(])(grep|rg|ag|ack|find|awk|sed|fgrep|egrep|jq|test|\[)([[:space:]]|$)'; then
  IS_SEARCH=1
fi

ERROR_DETECTED=0
ERROR_REASON=""

if [ "${EXIT_CODE:-0}" -ne 0 ]; then
  if [ "$IS_SEARCH" -eq 1 ] && [ "$EXIT_CODE" -lt 2 ]; then
    :
  else
    ERROR_DETECTED=1
    ERROR_REASON="exit code=${EXIT_CODE}"
  fi
fi

if [ "$ERROR_DETECTED" -eq 0 ] && [ "$IS_SEARCH" -eq 0 ]; then
  if printf '%s' "$STDERR_TEXT" | grep -qE '(^|[^a-zA-Z])(error|Error|ERROR|fail|Fail|FAIL|Exception|Traceback)([^a-zA-Z]|$)'; then
    ERROR_DETECTED=1
    ERROR_REASON="stderr matched error/fail/Exception pattern"
  fi
fi

if [ "$ERROR_DETECTED" -eq 0 ] && [ "$IS_SEARCH" -eq 0 ]; then
  if printf '%s' "$STDOUT_TEXT" | grep -qE '^[[:space:]]*(error|Error|ERROR|fail|Fail|FAIL):[[:space:]]'; then
    ERROR_DETECTED=1
    ERROR_REASON="stdout started with error/fail pattern"
  fi
fi

if [ "$ERROR_DETECTED" -eq 1 ]; then
  {
    echo "reason=$ERROR_REASON"
    echo "command=$COMMAND"
    echo "exit_code=$EXIT_CODE"
    echo "stderr_excerpt=$(printf '%s' "$STDERR_TEXT" | head -c 500)"
  } > "$CWD/.codex/.vdgg-error-pending"
fi

exit 0
