#!/bin/bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"

PRETOOL="$ROOT/.agents/skills/vibesdegogo/scripts/vdgg-hook-pretool.sh"
TMPDIR_VDGG=$(mktemp -d)
trap 'rm -rf "$TMPDIR_VDGG"' EXIT

write_state() {
    local phase="$1" step="$2" loop="${3:-0}" allowlist_file="${4:-}"
    mkdir -p "$TMPDIR_VDGG/.codex" "$TMPDIR_VDGG/tasks/vdgg/test-id"
    echo "test-id" > "$TMPDIR_VDGG/.codex/.vdgg-active"
    cat > "$TMPDIR_VDGG/.codex/.vdgg-state-test-id" <<EOF
step=${step}
phase=${phase}
loop_count=${loop}
current_task=T
task_allowlist_file=${allowlist_file}
task_base_ref=
vdgg_id=test-id
last_updated=2026-05-25T00:00:00Z
EOF
}

write_state_with_allowlist() {
    local phase="$1" step="$2" loop="${3:-0}"
    local allowlist="$TMPDIR_VDGG/.codex/.vdgg-task-allowlist-test-id-${loop}"
    mkdir -p "$TMPDIR_VDGG/.codex"
    printf 'functions/index.js\n' > "$allowlist"
    write_state "$phase" "$step" "$loop" "$allowlist"
}

run_hook() {
    local json="$1"
    set +e
    printf '%s' "$json" | bash "$PRETOOL" >/tmp/vdgg-test-pretool.out 2>/tmp/vdgg-test-pretool.err
    local status=$?
    set -e
    echo "$status"
}

write_state implementing 6
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"swift test"}}')
assert_exit_code 2 "$STATUS" "implementing blocks test commands"

write_state implementing 6
STATUS=$(run_hook '{"tool_name":"Edit","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"file_path":"'"$TMPDIR_VDGG"'/functions/index.js"}}')
assert_exit_code 2 "$STATUS" "implementing blocks edits before task allowlist"

write_state_with_allowlist implementing 6
STATUS=$(run_hook '{"tool_name":"Edit","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"file_path":"'"$TMPDIR_VDGG"'/functions/index.js"}}')
assert_exit_code 0 "$STATUS" "implementing allows edits inside task allowlist"

write_state_with_allowlist implementing 6
STATUS=$(run_hook '{"tool_name":"Edit","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"file_path":"'"$TMPDIR_VDGG"'/functions/other.js"}}')
assert_exit_code 2 "$STATUS" "implementing blocks edits outside task allowlist"

write_state testing 7
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"# [VibesDeGoGo! Step 7 Start] step=7, phase=verified, loop=0\nvdgg_state_advance 7 verified"}}')
assert_exit_code 2 "$STATUS" "verified transition is blocked without review sentinel"

write_state_with_allowlist testing 7
mkdir -p "$TMPDIR_VDGG/.codex"
cat > "$TMPDIR_VDGG/.codex/.vdgg-review-sentinel-test-id-0" <<EOF
started=1
modified=0
modified_files=
EOF
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"# [VibesDeGoGo! Step 7 Start] step=7, phase=verified, loop=0\nvdgg_state_advance 7 verified"}}')
assert_exit_code 2 "$STATUS" "verified transition is blocked without task gate"

write_state_with_allowlist testing 7
cat > "$TMPDIR_VDGG/.codex/.vdgg-review-sentinel-test-id-0" <<EOF
started=1
modified=0
modified_files=
EOF
cat > "$TMPDIR_VDGG/.codex/.vdgg-task-gate-test-id-0" <<EOF
passed=1
EOF
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"# [VibesDeGoGo! Step 7 Start] step=7, phase=verified, loop=0\nvdgg_state_advance 7 verified"}}')
assert_exit_code 0 "$STATUS" "verified transition passes after task gate and review sentinel"

write_state reflection 6
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"# [VibesDeGoGo! Step 6 Start] step=6, phase=implementing, loop=0\nvdgg_state_loop 6 implementing"}}')
assert_exit_code 0 "$STATUS" "Codex reflection retry transition is currently allowed by pretool"

write_state investigating 3
STATUS=$(run_hook '{"tool_name":"Edit","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"file_path":"'"$TMPDIR_VDGG"'/.codex/.vdgg-active"}}')
assert_exit_code 2 "$STATUS" "direct active file edit is blocked"

write_state investigating 3
STATUS=$(run_hook '{"tool_name":"Grep","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"pattern":"x"}}')
assert_exit_code 0 "$STATUS" "read-like tools pass during investigation"
