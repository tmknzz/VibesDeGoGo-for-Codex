#!/bin/bash
set -euo pipefail

: "${VDGG_CWD:=$(pwd)}"
VDGG_STATE_DIR="${VDGG_STATE_DIR:-${VDGG_CWD}/.codex}"
VDGG_TASKS_DIR="${VDGG_TASKS_DIR:-${VDGG_CWD}/tasks/vdgg}"

_vdgg_generate_id() {
  local timestamp random
  timestamp=$(date +%Y%m%d-%H%M)
  # Truncate to 4 hex chars to match the documented YYYYMMDD-HHMM-xxxx format
  # and stay in parity with the Claude edition.
  random=$(LC_ALL=C od -An -N8 -tx1 /dev/urandom | tr -d ' \n' | cut -c1-4)
  echo "${timestamp}-${random}"
}

_vdgg_active_file() { echo "${VDGG_STATE_DIR}/.vdgg-active"; }
_vdgg_state_file_for_id() { echo "${VDGG_STATE_DIR}/.vdgg-state-$1"; }
_vdgg_review_file_for_id() {
  local id="$1" loop="$2"
  echo "${VDGG_STATE_DIR}/.vdgg-review-sentinel-${id}-${loop}"
}

_vdgg_get_active_id() {
  local active_file
  active_file=$(_vdgg_active_file)
  [ -f "$active_file" ] && cat "$active_file" || true
}

_vdgg_get_state_file() {
  local id
  id=$(_vdgg_get_active_id)
  [ -n "$id" ] || return 1
  _vdgg_state_file_for_id "$id"
}

_vdgg_rm_glob() {
  [ -d "$1" ] || return 0
  find "$1" -maxdepth 1 -name "$2" -type f -exec rm -f {} + 2>/dev/null || true
}

_vdgg_check_step_transition() {
  local current="$1" next="$2"
  if ! [[ "$current" =~ ^[0-9]+$ ]] || ! [[ "$next" =~ ^[0-9]+$ ]]; then
    echo "vdgg-state: invalid or blocked state transition" >&2
    return 1
  fi
  if [ "$next" -eq "$current" ] || [ "$next" -eq $((current + 1)) ]; then
    return 0
  fi
  if [ "$current" -eq 8 ] && [ "$next" -eq 5 ]; then return 0; fi
  if [ "$current" -eq 7 ] && [ "$next" -eq 6 ]; then return 0; fi
  echo "vdgg-state: invalid or blocked state transition" >&2
  return 1
}

vdgg_get_id() {
  _vdgg_get_active_id
}

vdgg_state_init() {
  local id active_file state_file tasks_dir
  id=$(_vdgg_generate_id)
  active_file=$(_vdgg_active_file)
  state_file=$(_vdgg_state_file_for_id "$id")
  tasks_dir="${VDGG_TASKS_DIR}/${id}"

  if [ -f "$active_file" ]; then
    echo "vdgg-state: active VibesDeGoGo! session already exists" >&2
    return 1
  fi

  mkdir -p "$(dirname "$state_file")" "$tasks_dir"
  rm -f "${VDGG_STATE_DIR}/.vdgg-error-pending" 2>/dev/null || true
  _vdgg_rm_glob "${VDGG_STATE_DIR}" '.vdgg-review-sentinel-*'
  echo "$id" > "$active_file"
  cat > "$state_file" <<EOF
step=1
phase=declare
loop_count=0
current_task=
vdgg_id=${id}
last_updated=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  echo "vdgg-state: initialized id=${id}, state=${state_file}, tasks=${tasks_dir}" >&2
}

vdgg_state_read() {
  local state_file
  state_file=$(_vdgg_get_state_file || true)
  if [ -z "${state_file:-}" ] || [ ! -f "$state_file" ]; then
    printf 'step=0\nphase=none\nloop_count=0\ncurrent_task=\nvdgg_id=\nlast_updated=\n'
    return 1
  fi
  cat "$state_file"
}

vdgg_state_write() {
  local new_step="$1" new_phase="$2" new_loop_count="$3" new_current_task="${4:-}"
  local state_file current_step id

  [[ "$new_step" =~ ^[0-9]+$ ]] || { echo "vdgg-state: invalid step" >&2; return 1; }
  [[ "$new_phase" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "vdgg-state: invalid phase" >&2; return 1; }
  [[ "$new_loop_count" =~ ^[0-9]+$ ]] || { echo "vdgg-state: invalid loop" >&2; return 1; }

  state_file=$(_vdgg_get_state_file)
  [ -f "$state_file" ] || { echo "vdgg-state: state file not found" >&2; return 1; }
  current_step=$(grep '^step=' "$state_file" | cut -d= -f2)
  _vdgg_check_step_transition "${current_step:-0}" "$new_step"

  if [ -z "$new_current_task" ]; then
    new_current_task=$(grep '^current_task=' "$state_file" | cut -d= -f2- || true)
  fi
  id=$(_vdgg_get_active_id)
  cat > "$state_file" <<EOF
step=${new_step}
phase=${new_phase}
loop_count=${new_loop_count}
current_task=${new_current_task}
vdgg_id=${id}
last_updated=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  echo "vdgg-state: -> step=$new_step, phase=$new_phase, loop=$new_loop_count (id=$id)" >&2
}

vdgg_state_advance() {
  local next_step="$1" next_phase="$2" state_file current_loop current_task
  state_file=$(_vdgg_get_state_file)
  [ -f "$state_file" ] || { echo "vdgg_state_advance: state file not found" >&2; return 1; }
  current_loop=$(grep '^loop_count=' "$state_file" | cut -d= -f2)
  current_task=$(grep '^current_task=' "$state_file" | cut -d= -f2- || true)
  vdgg_state_write "$next_step" "$next_phase" "${current_loop:-0}" "$current_task"
}

vdgg_state_loop() {
  local loop_step="$1" loop_phase="$2" state_file current_loop current_task
  state_file=$(_vdgg_get_state_file)
  [ -f "$state_file" ] || { echo "vdgg_state_loop: state file not found" >&2; return 1; }
  current_loop=$(grep '^loop_count=' "$state_file" | cut -d= -f2)
  current_task=$(grep '^current_task=' "$state_file" | cut -d= -f2- || true)
  vdgg_state_write "$loop_step" "$loop_phase" "$(( ${current_loop:-0} + 1 ))" "$current_task"
}

vdgg_state_mark_reviewed() {
  local state_file id loop review_file
  state_file=$(_vdgg_get_state_file)
  [ -f "$state_file" ] || { echo "vdgg_state_mark_reviewed: state file not found" >&2; return 1; }
  id=$(_vdgg_get_active_id)
  loop=$(grep '^loop_count=' "$state_file" | cut -d= -f2)
  review_file=$(_vdgg_review_file_for_id "$id" "${loop:-0}")
  cat > "$review_file" <<EOF
started=1
started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
modified=0
modified_files=
EOF
  echo "vdgg-state: review gate marked for id=${id}, loop=${loop:-0}" >&2
}

vdgg_state_clear() {
  local id state_file
  id=$(_vdgg_get_active_id)
  [ -n "$id" ] || return 0
  state_file=$(_vdgg_state_file_for_id "$id")
  rm -f "$state_file" "$(_vdgg_active_file)" "${VDGG_STATE_DIR}/.vdgg-error-pending"
  _vdgg_rm_glob "${VDGG_STATE_DIR}" ".vdgg-review-sentinel-${id}-*"
  echo "vdgg-state: cleared id=${id}" >&2
}
