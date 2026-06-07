#!/bin/bash
set -euo pipefail

_vdgg_resolve_root() {
  local cwd="${1:-$(pwd)}"
  git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$cwd"
}

if [ -z "${VDGG_CWD:-}" ]; then
  VDGG_CWD=$(_vdgg_resolve_root "$(pwd)")
fi
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
_vdgg_task_allowlist_file_for_id() {
  local id="$1" loop="$2"
  echo "${VDGG_STATE_DIR}/.vdgg-task-allowlist-${id}-${loop}"
}
_vdgg_task_baseline_dir_for_id() {
  local id="$1" loop="$2"
  echo "${VDGG_STATE_DIR}/.vdgg-task-baseline-${id}-${loop}"
}
_vdgg_task_baseline_status_for_id() {
  local id="$1" loop="$2"
  echo "${VDGG_STATE_DIR}/.vdgg-task-baseline-status-${id}-${loop}"
}
_vdgg_task_gate_file_for_id() {
  local id="$1" loop="$2"
  echo "${VDGG_STATE_DIR}/.vdgg-task-gate-${id}-${loop}"
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

_vdgg_rm_dir_glob() {
  [ -d "$1" ] || return 0
  find "$1" -maxdepth 1 -name "$2" -type d -exec rm -rf {} + 2>/dev/null || true
}

_vdgg_normalize_path() {
  local path="$1"
  case "$path" in
    "$VDGG_CWD"/*) path="${path#"$VDGG_CWD"/}" ;;
    ./*) path="${path#./}" ;;
  esac
  printf '%s\n' "$path"
}

_vdgg_path_is_safe_relative() {
  local path
  path=$(_vdgg_normalize_path "$1")
  [ -n "$path" ] || return 1
  case "$path" in
    /*|../*|*/../*|..|.) return 1 ;;
  esac
  return 0
}

_vdgg_task_loop() {
  local state_file loop
  state_file=$(_vdgg_get_state_file)
  loop=$(grep '^loop_count=' "$state_file" | cut -d= -f2)
  printf '%s\n' "${loop:-0}"
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
task_allowlist_file=
task_base_ref=
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
  local state_file current_step id task_allowlist_file task_base_ref

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
  task_allowlist_file=$(grep '^task_allowlist_file=' "$state_file" | cut -d= -f2- || true)
  task_base_ref=$(grep '^task_base_ref=' "$state_file" | cut -d= -f2- || true)
  id=$(_vdgg_get_active_id)
  cat > "$state_file" <<EOF
step=${new_step}
phase=${new_phase}
loop_count=${new_loop_count}
current_task=${new_current_task}
task_allowlist_file=${task_allowlist_file}
task_base_ref=${task_base_ref}
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

vdgg_task_begin() {
  local task_title="${1:-}" id loop state_file allowlist_file baseline_dir baseline_status gate_file path normalized
  shift || true

  [ -n "$task_title" ] || { echo "vdgg_task_begin: task title is required" >&2; return 1; }
  [ "$#" -gt 0 ] || { echo "vdgg_task_begin: at least one allowlist path is required" >&2; return 1; }

  id=$(_vdgg_get_active_id)
  [ -n "$id" ] || { echo "vdgg_task_begin: active session not found" >&2; return 1; }
  loop=$(_vdgg_task_loop)
  state_file=$(_vdgg_get_state_file)
  allowlist_file=$(_vdgg_task_allowlist_file_for_id "$id" "$loop")
  baseline_dir=$(_vdgg_task_baseline_dir_for_id "$id" "$loop")
  baseline_status=$(_vdgg_task_baseline_status_for_id "$id" "$loop")
  gate_file=$(_vdgg_task_gate_file_for_id "$id" "$loop")

  rm -rf "$baseline_dir"
  rm -f "$gate_file"
  mkdir -p "$baseline_dir"
  : > "$allowlist_file"

  for path in "$@"; do
    _vdgg_path_is_safe_relative "$path" || {
      echo "vdgg_task_begin: unsafe allowlist path: $path" >&2
      return 1
    }
    normalized=$(_vdgg_normalize_path "$path")
    printf '%s\n' "$normalized" >> "$allowlist_file"
    if [ -e "$VDGG_CWD/$normalized" ]; then
      mkdir -p "$(dirname "$baseline_dir/$normalized")"
      cp -R "$VDGG_CWD/$normalized" "$baseline_dir/$normalized"
    fi
  done
  sort -u "$allowlist_file" -o "$allowlist_file"
  git -C "$VDGG_CWD" status --porcelain=v1 --untracked-files=all > "$baseline_status"

  vdgg_state_write 5 task-selected "$loop" "$task_title"
  if command -v perl >/dev/null 2>&1; then
    perl -0pi -e "s#task_allowlist_file=.*\\n#task_allowlist_file=${allowlist_file}\\n#; s#task_base_ref=.*\\n#task_base_ref=${baseline_status}\\n#" "$state_file"
  else
    sed -i.bak "s#^task_allowlist_file=.*#task_allowlist_file=${allowlist_file}#; s#^task_base_ref=.*#task_base_ref=${baseline_status}#" "$state_file"
    rm -f "$state_file.bak"
  fi
  echo "vdgg-task: began '${task_title}' with allowlist ${allowlist_file}" >&2
}

vdgg_task_changed_files() {
  local id loop baseline_status current_status
  id=$(_vdgg_get_active_id)
  [ -n "$id" ] || { echo "vdgg_task_changed_files: active session not found" >&2; return 1; }
  loop=$(_vdgg_task_loop)
  baseline_status=$(_vdgg_task_baseline_status_for_id "$id" "$loop")
  current_status=$(mktemp)
  git -C "$VDGG_CWD" status --porcelain=v1 --untracked-files=all > "$current_status"
  { [ -f "$baseline_status" ] && cat "$baseline_status"; cat "$current_status"; } \
    | sort | uniq -u | sed -E 's/^...//; s/^"//; s/"$//; s/.* -> //; /^\.codex\/\.vdgg-/d' \
    | sort -u
  rm -f "$current_status"
}

vdgg_task_check_allowlist() {
  local id loop allowlist_file changed file
  id=$(_vdgg_get_active_id)
  [ -n "$id" ] || { echo "vdgg_task_check_allowlist: active session not found" >&2; return 1; }
  loop=$(_vdgg_task_loop)
  allowlist_file=$(_vdgg_task_allowlist_file_for_id "$id" "$loop")
  [ -f "$allowlist_file" ] || { echo "vdgg_task_check_allowlist: allowlist not found" >&2; return 1; }
  changed=$(vdgg_task_changed_files)
  [ -n "$changed" ] || return 0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if ! grep -qxF "$file" "$allowlist_file"; then
      echo "vdgg-task: allowlist violation: $file" >&2
      return 1
    fi
  done <<EOF
$changed
EOF
}

vdgg_task_gate() {
  local id loop gate_file
  vdgg_task_check_allowlist || return 1
  if [ "$#" -gt 0 ]; then
    "$@" || return $?
  fi
  id=$(_vdgg_get_active_id)
  loop=$(_vdgg_task_loop)
  gate_file=$(_vdgg_task_gate_file_for_id "$id" "$loop")
  cat > "$gate_file" <<EOF
passed=1
passed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  echo "vdgg-task: gate passed for id=${id}, loop=${loop}" >&2
}

vdgg_task_rollback() {
  local id loop allowlist_file baseline_dir gate_file changed file
  id=$(_vdgg_get_active_id)
  [ -n "$id" ] || { echo "vdgg_task_rollback: active session not found" >&2; return 1; }
  loop=$(_vdgg_task_loop)
  allowlist_file=$(_vdgg_task_allowlist_file_for_id "$id" "$loop")
  baseline_dir=$(_vdgg_task_baseline_dir_for_id "$id" "$loop")
  gate_file=$(_vdgg_task_gate_file_for_id "$id" "$loop")
  [ -f "$allowlist_file" ] || { echo "vdgg_task_rollback: allowlist not found" >&2; return 1; }
  [ -d "$baseline_dir" ] || { echo "vdgg_task_rollback: baseline dir not found" >&2; return 1; }

  vdgg_task_check_allowlist || return 1
  rm -f "$gate_file"
  changed=$(vdgg_task_changed_files)
  [ -n "$changed" ] || return 0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if [ -e "$baseline_dir/$file" ]; then
      rm -rf "$VDGG_CWD/$file"
      mkdir -p "$(dirname "$VDGG_CWD/$file")"
      cp -R "$baseline_dir/$file" "$VDGG_CWD/$file"
    else
      rm -rf "$VDGG_CWD/$file"
    fi
  done <<EOF
$changed
EOF
  echo "vdgg-task: rolled back current task changes" >&2
}

vdgg_state_clear() {
  local id state_file
  id=$(_vdgg_get_active_id)
  [ -n "$id" ] || return 0
  state_file=$(_vdgg_state_file_for_id "$id")
  rm -f "$state_file" "$(_vdgg_active_file)" "${VDGG_STATE_DIR}/.vdgg-error-pending"
  _vdgg_rm_glob "${VDGG_STATE_DIR}" ".vdgg-review-sentinel-${id}-*"
  _vdgg_rm_glob "${VDGG_STATE_DIR}" ".vdgg-task-allowlist-${id}-*"
  _vdgg_rm_glob "${VDGG_STATE_DIR}" ".vdgg-task-baseline-status-${id}-*"
  _vdgg_rm_glob "${VDGG_STATE_DIR}" ".vdgg-task-gate-${id}-*"
  _vdgg_rm_dir_glob "${VDGG_STATE_DIR}" ".vdgg-task-baseline-${id}-*"
  echo "vdgg-state: cleared id=${id}" >&2
}
