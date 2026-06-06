#!/bin/bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"

POSTTOOL="$ROOT/.agents/skills/vibesdegogo/scripts/vdgg-hook-posttool.sh"
TMPDIR_VDGG=$(mktemp -d)
trap 'rm -rf "$TMPDIR_VDGG"' EXIT

write_state() {
    local phase="$1" step="$2"
    mkdir -p "$TMPDIR_VDGG/.codex"
    echo "test-id" > "$TMPDIR_VDGG/.codex/.vdgg-active"
    cat > "$TMPDIR_VDGG/.codex/.vdgg-state-test-id" <<EOF
step=${step}
phase=${phase}
loop_count=0
current_task=T
vdgg_id=test-id
last_updated=2026-05-25T00:00:00Z
EOF
}

run_hook() {
    local json="$1"
    set +e
    printf '%s' "$json" | bash "$POSTTOOL" >/tmp/vdgg-test-posttool.out 2>/tmp/vdgg-test-posttool.err
    local status=$?
    set -e
    echo "$status"
}

write_state implementing 6
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"make build"},"tool_response":{"exit_code":1,"stderr":"Error: failed"}}')
assert_exit_code 0 "$STATUS" "posttool itself exits cleanly after recording an error"
assert_file_exists "$TMPDIR_VDGG/.codex/.vdgg-error-pending" "failed Bash creates error flag"

rm -f "$TMPDIR_VDGG/.codex/.vdgg-error-pending"
write_state implementing 6
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"grep missing file"},"tool_response":{"exit_code":1,"stderr":""}}')
assert_exit_code 0 "$STATUS" "grep no-match exits cleanly"
assert_file_not_exists "$TMPDIR_VDGG/.codex/.vdgg-error-pending" "grep exit 1 does not create error flag"
