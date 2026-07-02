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

# Sentinel forgery: direct Write to a sentinel path is blocked.
write_state testing 7
STATUS=$(run_hook '{"tool_name":"Write","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"file_path":"'"$TMPDIR_VDGG"'/.codex/.vdgg-review-sentinel-test-id-0"}}')
assert_exit_code 2 "$STATUS" "direct sentinel write is blocked"

# Sentinel forgery: Bash heredoc write to a sentinel path is blocked.
write_state testing 7
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"cat > .codex/.vdgg-review-sentinel-test-id-0 <<EOF\nmodified=0\nEOF"}}')
assert_exit_code 2 "$STATUS" "bash sentinel forgery is blocked"

# P1-Both-2: a git commit segment must not shield a sidecar-mutating segment.
write_state commit 9
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"git commit -m x && rm -f .codex/.vdgg-active"}}')
assert_exit_code 2 "$STATUS" "git commit does not shield sidecar deletion"

# P1-CC-1: interpreter/tool-based sentinel forgery is blocked.
write_state testing 7
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"dd of=.codex/.vdgg-review-sentinel-test-id-0"}}')
assert_exit_code 2 "$STATUS" "dd sentinel forgery is blocked"

# P0-2: .vdgg-target is write-protected (agent cannot self-author REVIEW_COMMAND).
write_state implementing 6
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"echo REVIEW_COMMAND=true > .vdgg-target"}}')
assert_exit_code 2 "$STATUS" "bash write to .vdgg-target is blocked"

# Regression: a genuine sidecar read stays allowed.
write_state investigating 3
STATUS=$(run_hook '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"cat .codex/.vdgg-state-test-id"}}')
assert_exit_code 0 "$STATUS" "genuine sidecar read is allowed"

# jq missing: build a fakebin that exposes only the tools the fallback path uses.
# The fallback needs: cat grep sed head git.
FAKEBIN=$(mktemp -d)
BASH_BIN="$(command -v bash)"
for _tool in cat grep sed head git; do
  ln -s "$(command -v "$_tool")" "$FAKEBIN/$_tool"
done

# Case A: directory with no .codex/.vdgg-active and not a git repo -> exit 0.
NO_VDGG_DIR=$(mktemp -d)
set +e
printf '%s' '{"tool_name":"Bash","cwd":"'"$NO_VDGG_DIR"'","tool_input":{"command":"echo hi"}}' \
  | env PATH="$FAKEBIN" "$BASH_BIN" "$PRETOOL" >/dev/null 2>&1
STATUS=$?
set -e
assert_exit_code 0 "$STATUS" "jq missing + inactive session (no .codex/.vdgg-active) does not block"

# Case B: $TMPDIR_VDGG has .codex/.vdgg-active (write_state implementing 6 above
# left it in place). Not a git repo, so git toplevel resolution leaves cwd as-is,
# meaning the active file is found at $TMPDIR_VDGG/.codex/.vdgg-active -> exit 2.
write_state implementing 6
set +e
printf '%s' '{"tool_name":"Bash","cwd":"'"$TMPDIR_VDGG"'","tool_input":{"command":"echo hi"}}' \
  | env PATH="$FAKEBIN" "$BASH_BIN" "$PRETOOL" >/dev/null 2>&1
STATUS=$?
set -e
assert_exit_code 2 "$STATUS" "jq missing + active session fails closed"

rm -rf "$FAKEBIN" "$NO_VDGG_DIR"
