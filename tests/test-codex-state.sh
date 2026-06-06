#!/bin/bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"

TMPDIR_VDGG=$(mktemp -d)
trap 'rm -rf "$TMPDIR_VDGG"' EXIT

cd "$TMPDIR_VDGG" || exit 1
export VDGG_CWD="$TMPDIR_VDGG"

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
