#!/bin/bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"

TMPDIR_VDGG=$(mktemp -d)
trap 'rm -rf "$TMPDIR_VDGG"' EXIT

cd "$TMPDIR_VDGG" || exit 1
export VDGG_CWD="$TMPDIR_VDGG"
git init -q
git config user.email "vdgg-test@example.com"
git config user.name "VDGG Test"
mkdir -p functions
printf 'baseline\n' > functions/index.js
git add functions/index.js
git commit -q -m "baseline"

# The Codex state script uses set -euo pipefail; load it but disable errexit
# in the test driver so we can observe non-zero returns ourselves.
source "$ROOT/.agents/skills/vibesdegogo/scripts/vdgg-state.sh"
set +e

vdgg_state_init >/tmp/vdgg-test-codex-init.out 2>/tmp/vdgg-test-codex-init.err
ID=$(vdgg_get_id)
assert_ne "" "$ID" "Codex vdgg_state_init creates an id"
assert_file_exists ".codex/.vdgg-active" "Codex active file exists"
assert_file_exists ".codex/.vdgg-state-${ID}" "Codex state file exists"

RAND="${ID##*-}"
assert_eq "4" "${#RAND}" "Codex id random part is 4 chars (parity with Claude)"

vdgg_state_init >/tmp/vdgg-test-codex-init2.out 2>/tmp/vdgg-test-codex-init2.err
SECOND_INIT_RC=$?
assert_exit_code 1 "$SECOND_INIT_RC" "Codex re-init refuses while a session is active"
ERR_MSG=$(cat /tmp/vdgg-test-codex-init2.err)
assert_contains "$ERR_MSG" "active VibesDeGoGo! session already exists" "Codex re-init prints active-session message"

vdgg_state_advance 2 requirements >/tmp/vdgg-test-codex-2.out 2>/tmp/vdgg-test-codex-2.err
vdgg_state_advance 3 investigating >/tmp/vdgg-test-codex-3.out 2>/tmp/vdgg-test-codex-3.err
vdgg_state_advance 4 planning >/tmp/vdgg-test-codex-4.out 2>/tmp/vdgg-test-codex-4.err
vdgg_state_advance 5 task-selected >/tmp/vdgg-test-codex-5.out 2>/tmp/vdgg-test-codex-5.err
vdgg_task_begin "T1: allowlist probe" functions/index.js functions/new.js >/tmp/vdgg-test-codex-task.out 2>/tmp/vdgg-test-codex-task.err
assert_file_exists ".codex/.vdgg-task-allowlist-${ID}-0" "Codex task allowlist file exists"
ALLOWLIST=$(cat ".codex/.vdgg-task-allowlist-${ID}-0")
assert_contains "$ALLOWLIST" "functions/index.js" "Codex task allowlist includes tracked file"
assert_contains "$ALLOWLIST" "functions/new.js" "Codex task allowlist includes new file"
assert_file_exists ".codex/.vdgg-task-baseline-status-${ID}-0" "Codex task baseline status exists"
assert_file_exists ".codex/.vdgg-task-baseline-${ID}-0/functions/index.js" "Codex task baseline copies existing file"
STATE_CONTENT=$(cat ".codex/.vdgg-state-${ID}")
assert_contains "$STATE_CONTENT" "task_allowlist_file=" "Codex state records task allowlist field"
assert_contains "$STATE_CONTENT" "task_base_ref=" "Codex state records task baseline field"

printf 'changed\n' > functions/index.js
printf 'new\n' > functions/new.js
CHANGED=$(vdgg_task_changed_files)
assert_contains "$CHANGED" "functions/index.js" "Codex task changed files include modified allowlisted file"
assert_contains "$CHANGED" "functions/new.js" "Codex task changed files include new allowlisted file"
vdgg_task_check_allowlist >/tmp/vdgg-test-codex-allow.out 2>/tmp/vdgg-test-codex-allow.err
ALLOW_RC=$?
assert_exit_code 0 "$ALLOW_RC" "Codex task allowlist passes allowed changes"
vdgg_task_gate true >/tmp/vdgg-test-codex-gate.out 2>/tmp/vdgg-test-codex-gate.err
GATE_RC=$?
assert_exit_code 0 "$GATE_RC" "Codex task gate passes after allowlist and command"
assert_file_exists ".codex/.vdgg-task-gate-${ID}-0" "Codex task gate writes success sentinel"
vdgg_task_rollback >/tmp/vdgg-test-codex-rollback.out 2>/tmp/vdgg-test-codex-rollback.err
ROLLBACK_RC=$?
assert_exit_code 0 "$ROLLBACK_RC" "Codex task rollback succeeds for allowed changes"
INDEX_CONTENT=$(cat functions/index.js)
assert_eq "baseline" "$INDEX_CONTENT" "Codex task rollback restores modified file"
assert_file_not_exists "functions/new.js" "Codex task rollback removes newly-created file"
assert_file_not_exists ".codex/.vdgg-task-gate-${ID}-0" "Codex task rollback clears gate sentinel"
printf 'outside\n' > functions/other.js
vdgg_task_check_allowlist >/tmp/vdgg-test-codex-deny.out 2>/tmp/vdgg-test-codex-deny.err
DENY_RC=$?
assert_exit_code 1 "$DENY_RC" "Codex task allowlist rejects disallowed changes"
rm -f functions/other.js
vdgg_state_advance 6 implementing >/tmp/vdgg-test-codex-6.out 2>/tmp/vdgg-test-codex-6.err
vdgg_state_loop 6 implementing >/tmp/vdgg-test-codex-loop.out 2>/tmp/vdgg-test-codex-loop.err
LOOP_COUNT=$(grep '^loop_count=' ".codex/.vdgg-state-${ID}" | cut -d= -f2)
assert_eq "1" "$LOOP_COUNT" "Codex vdgg_state_loop increments loop_count"

vdgg_state_advance 7 testing >/tmp/vdgg-test-codex-7.out 2>/tmp/vdgg-test-codex-7.err
vdgg_state_mark_reviewed >/tmp/vdgg-test-codex-review.out 2>/tmp/vdgg-test-codex-review.err
assert_file_exists ".codex/.vdgg-review-sentinel-${ID}-1" "Codex mark_reviewed creates review sentinel"
MODIFIED=$(grep '^modified=' ".codex/.vdgg-review-sentinel-${ID}-1" | cut -d= -f2)
assert_eq "0" "$MODIFIED" "Codex review sentinel starts with modified=0"

vdgg_state_clear >/tmp/vdgg-test-codex-clear.out 2>/tmp/vdgg-test-codex-clear.err
assert_file_not_exists ".codex/.vdgg-active" "Codex clear removes active file"
assert_file_not_exists ".codex/.vdgg-state-${ID}" "Codex clear removes state file"
assert_file_not_exists ".codex/.vdgg-review-sentinel-${ID}-1" "Codex clear removes review sentinels"
