#!/usr/bin/env bash
# Tests for the SDD workspace: scripts/sdd-workspace resolves a self-ignoring
# working-tree directory for SDD artifacts, and the SDD scripts write into it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDD_SCRIPTS="$REPO_ROOT/skills/subagent-driven-development/scripts"

FAILURES=0
TEST_ROOT=""

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

cleanup() {
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}

canonical_task() {
    local title=${1:-Canonical parser}
    local files=${2:-'- Modify: `src/parser.sh`
- Test: `tests/parser.sh`'}
    local extra=${3:-}
    cat <<EOF
### Task 1: $title

**Files:**
$files

**Focused behavior:** Parse one bounded canonical task into durable artifacts.

**Test intent:** Verify the parser accepts valid input and rejects invalid input precisely.

**Inherited interfaces:**
- None

**Out of scope:**
- Arbitrary Markdown extensions

**Done when:** The brief and manifest are published together.

**Review intent:** Review task-local parsing now and defer branch-wide integration.
$extra
EOF
}

run_task_brief() {
    local repo=$1
    shift
    set +e
    (cd "$repo" && "$SDD_SCRIPTS/task-brief" "$@") >"$repo/stdout" 2>"$repo/stderr"
    TASK_BRIEF_STATUS=$?
    set -e
}

assert_case() {
    local label=$1
    shift
    if "$@"; then
        pass "$label"
    else
        fail "$label"
        [[ -f "$CASE_ROOT/stderr" ]] && sed 's/^/    stderr: /' "$CASE_ROOT/stderr"
    fi
}

new_case() {
    local label=$1
    CASE_ROOT="$TEST_ROOT/$label"
    git init -q -b main "$CASE_ROOT"
}

task_brief_accepts_canonical_v1() {
    new_case "$FUNCNAME"
    canonical_task >"$CASE_ROOT/plan.md"
    run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json --report report.md
    [[ $TASK_BRIEF_STATUS -eq 0 ]] || return 1
    cmp -s "$CASE_ROOT/plan.md" "$CASE_ROOT/brief.md" || return 1
    python3 - "$CASE_ROOT/manifest.json" "$CASE_ROOT/brief.md" "$CASE_ROOT/report.md" <<'PY'
import json, sys
manifest_path, brief, report = sys.argv[1:]
with open(manifest_path, encoding="utf-8") as stream:
    value = json.load(stream)
expected = {
    "version": 1,
    "task": 1,
    "title": "Canonical parser",
    "brief": "brief.md",
    "report": "report.md",
    "focused_behavior": "Parse one bounded canonical task into durable artifacts.",
    "production_files": ["src/parser.sh"],
    "test_intent": "Verify the parser accepts valid input and rejects invalid input precisely.",
    "inherited_interfaces": [],
    "out_of_scope": ["Arbitrary Markdown extensions"],
    "done_when": "The brief and manifest are published together.",
    "review_intent": "Review task-local parsing now and defer branch-wide integration.",
    "cohesion_override": None,
}
assert value == expected, (value, expected)
PY
}

task_brief_ignores_backtick_and_tilde_fenced_headings() {
    new_case "$FUNCNAME"
    {
        cat <<'EOF'
```markdown
### Task 1: Backtick decoy
```
~~~markdown
### Task 1: Tilde decoy
~~~
EOF
        canonical_task
    } >"$CASE_ROOT/plan.md"
    run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json
    [[ $TASK_BRIEF_STATUS -eq 0 ]] || return 1
    [[ $(grep -c '^### Task 1:' "$CASE_ROOT/brief.md") -eq 1 ]] || return 1
    grep -q '^### Task 1: Canonical parser$' "$CASE_ROOT/brief.md"
}

task_brief_rejects_missing_heading_exit_3() {
    new_case "$FUNCNAME"
    canonical_task | sed 's/^### Task 1:/### Task 2:/' >"$CASE_ROOT/plan.md"
    run_task_brief "$CASE_ROOT" plan.md 1
    [[ $TASK_BRIEF_STATUS -eq 3 ]]
}

task_brief_rejects_duplicate_heading_exit_3() {
    new_case "$FUNCNAME"
    { canonical_task; printf '\n'; canonical_task Duplicate; } >"$CASE_ROOT/plan.md"
    run_task_brief "$CASE_ROOT" plan.md 1
    [[ $TASK_BRIEF_STATUS -eq 3 ]]
}

task_brief_rejects_missing_duplicate_or_empty_slots_exit_2() {
    new_case "$FUNCNAME"
    local kind status
    for kind in missing duplicate empty; do
        canonical_task >"$CASE_ROOT/$kind.md"
    done
    sed -i '/^\*\*Test intent:\*\*/d' "$CASE_ROOT/missing.md"
    sed -i '/^\*\*Done when:\*\*/p' "$CASE_ROOT/duplicate.md"
    sed -i 's/^\*\*Focused behavior:\*\*.*/**Focused behavior:**   /' "$CASE_ROOT/empty.md"
    for kind in missing duplicate empty; do
        run_task_brief "$CASE_ROOT" "$kind.md" 1 "$kind-brief.md" --manifest "$kind-manifest.json"
        status=$TASK_BRIEF_STATUS
        [[ $status -eq 2 ]] || return 1
        grep -qi "$kind" "$CASE_ROOT/stderr" || return 1
    done
}

make_sized_plan() {
    local destination=$1 size=$2
    canonical_task >"$destination"
    python3 - "$destination" "$size" <<'PY'
import sys
path, target = sys.argv[1], int(sys.argv[2])
with open(path, "rb") as stream:
    value = stream.read()
needle = b"- Arbitrary Markdown extensions"
padding = target - len(value)
assert padding >= 0
value = value.replace(needle, needle + b"x" * padding, 1)
assert len(value) == target
with open(path, "wb") as stream:
    stream.write(value)
PY
}

task_brief_accepts_exact_32768_byte_boundary() {
    new_case "$FUNCNAME"
    make_sized_plan "$CASE_ROOT/plan.md" 32768
    run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json
    [[ $TASK_BRIEF_STATUS -eq 0 && $(wc -c <"$CASE_ROOT/brief.md") -eq 32768 ]]
}

task_brief_rejects_32769_bytes_exit_4() {
    new_case "$FUNCNAME"
    make_sized_plan "$CASE_ROOT/plan.md" 32769
    run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json --max-bytes 32769
    [[ $TASK_BRIEF_STATUS -eq 4 && ! -e "$CASE_ROOT/brief.md" && ! -e "$CASE_ROOT/manifest.json" ]]
}

task_brief_requires_cohesion_override_for_shape_warnings() {
    new_case "$FUNCNAME"
    local files='- Modify: `pkg-a/one.sh`
- Modify: `pkg-b/two.sh`'
    canonical_task Warning "$files" >"$CASE_ROOT/plan.md"
    run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json
    [[ $TASK_BRIEF_STATUS -eq 2 ]] || return 1
    canonical_task Warning "$files" $'\n**Cohesion override:** The cross-package change is one atomic interface update.' >"$CASE_ROOT/plan.md"
    run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json
    [[ $TASK_BRIEF_STATUS -eq 0 ]] || return 1
    python3 - "$CASE_ROOT/manifest.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    value = json.load(stream)
assert value["cohesion_override"] == "The cross-package change is one atomic interface update."
PY
}

task_brief_does_not_treat_file_count_as_hard_failure() {
    new_case "$FUNCNAME"
    local files='- Modify: `pkg/one.sh`
- Modify: `pkg/two.sh`
- Modify: `pkg/three.sh`
- Modify: `pkg/four.sh`
- Modify: `pkg/five.sh`'
    canonical_task Many "$files" >"$CASE_ROOT/plan.md"
    run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json
    [[ $TASK_BRIEF_STATUS -eq 2 ]] || return 1
    canonical_task Many "$files" $'\n**Cohesion override:** Five production files implement one indivisible parser boundary.' >"$CASE_ROOT/plan.md"
    run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json
    [[ $TASK_BRIEF_STATUS -eq 0 ]]
}

task_brief_preserves_existing_outputs_on_failure() {
    new_case "$FUNCNAME"
    printf 'old brief\n' >"$CASE_ROOT/brief.md"
    printf 'old manifest\n' >"$CASE_ROOT/manifest.json"
    make_sized_plan "$CASE_ROOT/plan.md" 32769
    run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json
    [[ $TASK_BRIEF_STATUS -eq 4 ]] || return 1
    [[ $(cat "$CASE_ROOT/brief.md") == 'old brief' && $(cat "$CASE_ROOT/manifest.json") == 'old manifest' ]]
}

task_brief_leaves_no_temporary_artifacts() {
    new_case "$FUNCNAME"
    make_sized_plan "$CASE_ROOT/plan.md" 32769
    run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json
    [[ $TASK_BRIEF_STATUS -eq 4 ]] || return 1
    [[ -z $(find "$CASE_ROOT" -maxdepth 1 -type f \( -name '*.tmp' -o -name '.*.tmp.*' \) -print) ]]
}

task_brief_reports_only_paths_and_byte_counts() {
    new_case "$FUNCNAME"
    canonical_task >"$CASE_ROOT/plan.md"
    run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json
    [[ $TASK_BRIEF_STATUS -eq 0 ]] || return 1
    [[ $(wc -l <"$CASE_ROOT/stdout") -eq 2 ]] || return 1
    grep -Eq '^brief\.md: [0-9]+ bytes$' "$CASE_ROOT/stdout" || return 1
    grep -Eq '^manifest\.json: [0-9]+ bytes$' "$CASE_ROOT/stdout"
}

task_brief_rejects_output_path_escape() {
    new_case "$FUNCNAME"
    canonical_task >"$CASE_ROOT/plan.md"
    run_task_brief "$CASE_ROOT" plan.md 1 ../brief.md --manifest manifest.json --report ../report.md
    [[ $TASK_BRIEF_STATUS -eq 2 ]] || return 1
    grep -q 'escapes repository root' "$CASE_ROOT/stderr" || return 1
    [[ ! -e "$TEST_ROOT/brief.md" && ! -e "$TEST_ROOT/report.md" ]]
}

task_brief_atomic_publication_failure_exit_5() {
    new_case "$FUNCNAME"
    canonical_task >"$CASE_ROOT/plan.md"
    printf 'old brief\n' >"$CASE_ROOT/brief.md"
    printf 'old manifest\n' >"$CASE_ROOT/manifest.json"
    SUPERPOWERS_TASK_BRIEF_FAIL_AFTER_INSTALL=1 \
        run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json
    [[ $TASK_BRIEF_STATUS -eq 5 ]] || return 1
    grep -q 'injected failure after destination install 1' "$CASE_ROOT/stderr" || return 1
    [[ $(cat "$CASE_ROOT/brief.md") == 'old brief' ]] || return 1
    [[ $(cat "$CASE_ROOT/manifest.json") == 'old manifest' ]] || return 1
    [[ -z $(find "$CASE_ROOT" -maxdepth 1 -type f -name '.task-brief*.tmp' -print) ]]
}

task_brief_backup_cleanup_failure_after_one_unlink_is_committed() {
    new_case "$FUNCNAME"
    canonical_task >"$CASE_ROOT/plan.md"
    printf 'old brief\n' >"$CASE_ROOT/brief.md"
    printf 'old manifest\n' >"$CASE_ROOT/manifest.json"
    SUPERPOWERS_TASK_BRIEF_FAIL_BACKUP_CLEANUP=2 \
        run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json
    [[ $TASK_BRIEF_STATUS -eq 0 ]] || return 1
    grep -q 'injected failure during backup unlink 2' "$CASE_ROOT/stderr" || return 1
    cmp -s "$CASE_ROOT/plan.md" "$CASE_ROOT/brief.md" || return 1
    python3 - "$CASE_ROOT/manifest.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    assert json.load(stream)["task"] == 1
PY
    local backup
    [[ $(find "$CASE_ROOT" -maxdepth 1 -type f -name '.task-brief-backup.*.tmp' -print | wc -l) -eq 1 ]] || return 1
    backup=$(find "$CASE_ROOT" -maxdepth 1 -type f -name '.task-brief-backup.*.tmp' -print)
    [[ $(cat "$backup") == 'old manifest' ]] || return 1
    [[ -z $(find "$CASE_ROOT" -maxdepth 1 -type f -name '.task-brief.*.tmp' -print) ]]
}

task_brief_absent_outputs_rollback_after_first_install_exit_5() {
    new_case "$FUNCNAME"
    canonical_task >"$CASE_ROOT/plan.md"
    SUPERPOWERS_TASK_BRIEF_FAIL_AFTER_INSTALL=1 \
        run_task_brief "$CASE_ROOT" plan.md 1 brief.md --manifest manifest.json
    [[ $TASK_BRIEF_STATUS -eq 5 ]] || return 1
    grep -q 'injected failure after destination install 1' "$CASE_ROOT/stderr" || return 1
    [[ ! -e "$CASE_ROOT/brief.md" ]] || return 1
    [[ ! -e "$CASE_ROOT/manifest.json" ]] || return 1
    [[ -z $(find "$CASE_ROOT" -maxdepth 1 -type f -name '.task-brief*.tmp' -print) ]]
}

run_task_brief_cases() {
    local label
    for label in \
        task_brief_accepts_canonical_v1 \
        task_brief_ignores_backtick_and_tilde_fenced_headings \
        task_brief_rejects_missing_heading_exit_3 \
        task_brief_rejects_duplicate_heading_exit_3 \
        task_brief_rejects_missing_duplicate_or_empty_slots_exit_2 \
        task_brief_accepts_exact_32768_byte_boundary \
        task_brief_rejects_32769_bytes_exit_4 \
        task_brief_requires_cohesion_override_for_shape_warnings \
        task_brief_does_not_treat_file_count_as_hard_failure \
        task_brief_preserves_existing_outputs_on_failure \
        task_brief_leaves_no_temporary_artifacts \
        task_brief_reports_only_paths_and_byte_counts \
        task_brief_rejects_output_path_escape \
        task_brief_atomic_publication_failure_exit_5 \
        task_brief_backup_cleanup_failure_after_one_unlink_is_committed \
        task_brief_absent_outputs_rollback_after_first_install_exit_5
    do
        assert_case "$label" "$label"
    done
}

sdd_state_case() {
    local name=$1; shift
    new_case "$name"
    local base head
    ( cd "$CASE_ROOT" && git -c user.email=t@example.com -c user.name=t commit --allow-empty -qm base )
    base=$(cd "$CASE_ROOT" && git rev-parse HEAD)
    printf 'x\n' > "$CASE_ROOT/file"
    ( cd "$CASE_ROOT" && git add file && git -c user.email=t@example.com -c user.name=t commit -qm impl )
    head=$(cd "$CASE_ROOT" && git rev-parse HEAD)
    ( cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" init task-1 "$base" "$head" >/dev/null ) || return 1
    ( cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" "$@" >/dev/null )
}

sdd_state_initializes_v1() {
    sdd_state_case "$FUNCNAME" status || return 1
    python3 - "$CASE_ROOT/.superpowers/sdd/state.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); assert s['version']==1 and s['state']=='pending'
assert s['task_base'] and s['implementation_head'] and s['reviewed_head'] is None
PY
}
sdd_state_accepts_all_declared_transitions() {
    sdd_state_case "$FUNCNAME" transition implementing || return 1
    for x in implemented reviewing approved complete; do
      (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" transition "$x" >/dev/null) || return 1
    done
}
sdd_state_rejects_invalid_transition_with_corrective_command() {
    sdd_state_case "$FUNCNAME" status || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" transition approved >/dev/null 2>e) && return 1
    grep -q 'current state pending' "$CASE_ROOT/e" && grep -q 'transition implementing' "$CASE_ROOT/e"
}
sdd_state_corrective_diagnostic_is_deterministic() {
    sdd_state_case "$FUNCNAME" transition implementing || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" transition implemented >/dev/null && "$SDD_SCRIPTS/sdd-state" transition reviewing >/dev/null && "$SDD_SCRIPTS/sdd-state" transition complete >/dev/null 2>e) && return 1
    grep -q 'corrective command: sdd-state transition approved' "$CASE_ROOT/e"
}
sdd_state_rejects_rereview_from_task_base() {
    sdd_state_case "$FUNCNAME" transition implementing || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" transition implemented >/dev/null && "$SDD_SCRIPTS/sdd-state" transition reviewing >/dev/null && "$SDD_SCRIPTS/sdd-state" transition needs_fixes >/dev/null && "$SDD_SCRIPTS/sdd-state" transition fixing >/dev/null) || return 1
    python3 - "$CASE_ROOT/.superpowers/sdd/state.json" <<'PY'
import json,sys
p=sys.argv[1]; s=json.load(open(p)); s['reviewed_head']=s['task_base']; json.dump(s,open(p,'w'),indent=2); open(p,'a').write('\\n'.encode().decode('unicode_escape'))
PY
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" transition rereviewing >/dev/null 2>e) && return 1
    grep -q 'task base' "$CASE_ROOT/e"
}
sdd_state_rejects_unchanged_and_nondescendant_heads() {
    sdd_state_case "$FUNCNAME" transition implementing || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" transition implemented >/dev/null && "$SDD_SCRIPTS/sdd-state" transition reviewing >/dev/null && "$SDD_SCRIPTS/sdd-state" transition needs_fixes >/dev/null && "$SDD_SCRIPTS/sdd-state" transition fixing >/dev/null) || return 1
    local reviewed=$(cd "$CASE_ROOT" && git rev-parse HEAD)
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" transition rereviewing --head HEAD >/dev/null 2>e) && return 1
    grep -q 'must change' "$CASE_ROOT/e" || return 1
    (cd "$CASE_ROOT" && git checkout -q --detach HEAD~1 && "$SDD_SCRIPTS/sdd-state" transition rereviewing --head HEAD >/dev/null 2>e) && return 1
    grep -q 'descendant of reviewed head' "$CASE_ROOT/e"
}
sdd_state_updates_reviewed_head_on_multiple_rereviews() {
    sdd_state_case "$FUNCNAME" transition implementing || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" transition implemented >/dev/null && "$SDD_SCRIPTS/sdd-state" transition reviewing >/dev/null && "$SDD_SCRIPTS/sdd-state" transition needs_fixes >/dev/null && "$SDD_SCRIPTS/sdd-state" transition fixing >/dev/null)
    printf 'y\n' > "$CASE_ROOT/second"; (cd "$CASE_ROOT" && git add second && git -c user.email=t@example.com -c user.name=t commit -qm second)
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" transition rereviewing --head HEAD >/dev/null && "$SDD_SCRIPTS/sdd-state" transition needs_fixes >/dev/null && "$SDD_SCRIPTS/sdd-state" transition fixing >/dev/null)
    printf 'z\n' > "$CASE_ROOT/third"; (cd "$CASE_ROOT" && git add third && git -c user.email=t@example.com -c user.name=t commit -qm third)
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" transition rereviewing --head HEAD >/dev/null)
    python3 - "$CASE_ROOT/.superpowers/sdd/state.json" <<'PY'
import json,sys,subprocess
s=json.load(open(sys.argv[1])); assert s['reviewed_head']==subprocess.check_output(['git','-C',sys.argv[1].split('/.superpowers')[0],'rev-parse','HEAD'],text=True).strip()
PY
}
sdd_state_rejects_duplicate_and_malformed_finding_ids() {
    sdd_state_case "$FUNCNAME" status || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" record --findings 'C1:Minor,C1:Important' >/dev/null 2>e) && return 1
    grep -q 'duplicate finding ID' "$CASE_ROOT/e" || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" record --findings 'bad_id:Minor' >/dev/null 2>e) && return 1
    grep -q 'malformed finding ID' "$CASE_ROOT/e"
}
sdd_state_rejects_metadata_heads_and_malformed_findings() {
    sdd_state_case "$FUNCNAME" status || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" record --findings 'bad-token' >/dev/null 2>e) && return 1
    grep -q 'malformed finding' "$CASE_ROOT/e" || return 1
    (cd "$CASE_ROOT" && git checkout -q --orphan unrelated && git rm -q -rf . && git -c user.email=t@example.com -c user.name=t commit --allow-empty -qm unrelated)
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" record --fix-head HEAD >/dev/null 2>e) && return 1
    grep -q 'descendant of task base' "$CASE_ROOT/e" || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" record --approved-head HEAD >/dev/null 2>e) && return 1
    grep -q 'approved head.*descendant of task base' "$CASE_ROOT/e"
}
sdd_state_records_exact_json_fields() {
    sdd_state_case "$FUNCNAME" status || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" record --package pkg/manifest.json --report report.md --findings C1:Important,F2:Minor --fix-head HEAD --approved-head HEAD >/dev/null)
    python3 - "$CASE_ROOT/.superpowers/sdd/state.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); assert s['open_findings']==[{'id':'C1','severity':'Important'},{'id':'F2','severity':'Minor'}]
assert s['package_manifest']=='pkg/manifest.json' and s['review_report']=='report.md'
assert len(s['fix_head'])==40 and len(s['final_approved_head'])==40
PY
}
sdd_state_rejects_approved_with_open_critical_or_important() {
    sdd_state_case "$FUNCNAME" transition implementing || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" transition implemented >/dev/null && "$SDD_SCRIPTS/sdd-state" transition reviewing >/dev/null && "$SDD_SCRIPTS/sdd-state" record --findings C1:Critical >/dev/null && "$SDD_SCRIPTS/sdd-state" transition approved >/dev/null 2>e) && return 1
    grep -q 'blocking' "$CASE_ROOT/e"
}
sdd_state_rejects_complete_with_open_critical_or_important() {
    sdd_state_case "$FUNCNAME" transition implementing || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" transition implemented >/dev/null && "$SDD_SCRIPTS/sdd-state" transition reviewing >/dev/null && "$SDD_SCRIPTS/sdd-state" record --findings C1:Critical >/dev/null && "$SDD_SCRIPTS/sdd-state" transition approved --findings C1:Critical >/dev/null 2>e && "$SDD_SCRIPTS/sdd-state" transition complete >/dev/null 2>e) && return 1
    grep -q 'blocking' "$CASE_ROOT/e"
}
sdd_state_rereview_defaults_to_recorded_fix_head() {
    sdd_state_case "$FUNCNAME" transition implementing || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" transition implemented >/dev/null && "$SDD_SCRIPTS/sdd-state" transition reviewing >/dev/null && "$SDD_SCRIPTS/sdd-state" transition needs_fixes >/dev/null && "$SDD_SCRIPTS/sdd-state" transition fixing >/dev/null)
    printf 'fix\n' > "$CASE_ROOT/fix"; (cd "$CASE_ROOT" && git add fix && git -c user.email=t@example.com -c user.name=t commit -qm fix)
    local fix_head=$(cd "$CASE_ROOT" && git rev-parse HEAD)
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" record --fix-head HEAD >/dev/null && "$SDD_SCRIPTS/sdd-state" transition rereviewing >/dev/null) || return 1
    python3 - "$CASE_ROOT/.superpowers/sdd/state.json" "$fix_head" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))['reviewed_head'] == sys.argv[2]
PY
}
sdd_state_records_package_report_findings_fix_and_approved_heads() {
    sdd_state_case "$FUNCNAME" status || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" record --package pkg/manifest.json --report report.md --findings C1:Important --fix-head HEAD --approved-head HEAD >/dev/null)
    grep -q 'pkg/manifest.json' "$CASE_ROOT/.superpowers/sdd/state.json" && grep -q 'report.md' "$CASE_ROOT/.superpowers/sdd/state.json"
}
sdd_state_updates_json_atomically() {
    sdd_state_case "$FUNCNAME" transition implementing || return 1
    cp "$CASE_ROOT/.superpowers/sdd/state.json" "$CASE_ROOT/state.before"
    cp "$CASE_ROOT/.superpowers/sdd/progress.md" "$CASE_ROOT/ledger.before"
    (cd "$CASE_ROOT" && SUPERPOWERS_SDD_FAIL_AFTER_INSTALL=1 "$SDD_SCRIPTS/sdd-state" transition implemented >/dev/null 2>e) && return 1
    cmp -s "$CASE_ROOT/state.before" "$CASE_ROOT/.superpowers/sdd/state.json" && cmp -s "$CASE_ROOT/ledger.before" "$CASE_ROOT/.superpowers/sdd/progress.md"
}
sdd_state_appends_concise_progress_atomically() {
    sdd_state_case "$FUNCNAME" transition implementing || return 1
    [[ $(wc -l <"$CASE_ROOT/.superpowers/sdd/progress.md") -ge 2 ]] || return 1
    grep -q 'implementing' "$CASE_ROOT/.superpowers/sdd/progress.md" && ! find "$CASE_ROOT/.superpowers/sdd" -name '*.tmp*' | grep -q .
}
sdd_state_recovers_after_crash_between_publications() {
    sdd_state_case "$FUNCNAME" transition implementing || return 1
    set +e
    (cd "$CASE_ROOT" && SUPERPOWERS_SDD_CRASH_AFTER_STATE_INSTALL=1 "$SDD_SCRIPTS/sdd-state" transition implemented >/dev/null 2>e)
    local status=$?
    set -e
    [[ $status -ne 0 && -f "$CASE_ROOT/.superpowers/sdd/.publish.pending" ]] || return 1
    (cd "$CASE_ROOT" && "$SDD_SCRIPTS/sdd-state" status >/dev/null) || return 1
    python3 - "$CASE_ROOT/.superpowers/sdd/state.json" "$CASE_ROOT/.superpowers/sdd/progress.md" <<'PY'
import json,sys
state=json.load(open(sys.argv[1])); ledger=open(sys.argv[2]).read()
assert state['state']=='implemented'
assert '- implemented ' in ledger
PY
    [[ ! -e "$CASE_ROOT/.superpowers/sdd/.publish.pending" ]]
}

run_sdd_state_cases() {
    for label in sdd_state_initializes_v1 sdd_state_accepts_all_declared_transitions sdd_state_rejects_invalid_transition_with_corrective_command sdd_state_corrective_diagnostic_is_deterministic sdd_state_rejects_rereview_from_task_base sdd_state_rejects_unchanged_and_nondescendant_heads sdd_state_updates_reviewed_head_on_multiple_rereviews sdd_state_rejects_metadata_heads_and_malformed_findings sdd_state_records_exact_json_fields sdd_state_rejects_approved_with_open_critical_or_important sdd_state_rejects_complete_with_open_critical_or_important sdd_state_rejects_duplicate_and_malformed_finding_ids sdd_state_rereview_defaults_to_recorded_fix_head sdd_state_records_package_report_findings_fix_and_approved_heads sdd_state_updates_json_atomically sdd_state_appends_concise_progress_atomically sdd_state_recovers_after_crash_between_publications; do assert_case "$label" "$label"; done
}

main() {
    echo "=== Test: sdd-workspace ==="

    TEST_ROOT="$(mktemp -d)"
    trap cleanup EXIT

    # Resolve repo to its physical path so string comparisons match the
    # helper's output (git rev-parse --show-toplevel resolves symlinks; on
    # macOS mktemp lives under /var -> /private/var).
    git init -q -b main "$TEST_ROOT/repo"
    local repo
    repo="$(cd "$TEST_ROOT/repo" && git rev-parse --show-toplevel)"

    local dir
    dir="$(cd "$repo" && "$SDD_SCRIPTS/sdd-workspace")"

    if [[ "$dir" == "$repo/.superpowers/sdd" ]]; then
        pass "prints <repo-root>/.superpowers/sdd"
    else
        fail "prints <repo-root>/.superpowers/sdd"
        echo "    got: $dir"
    fi

    if [[ -f "$repo/.superpowers/sdd/.gitignore" && "$(cat "$repo/.superpowers/sdd/.gitignore")" == "*" ]]; then
        pass "self-ignoring .gitignore created with '*'"
    else
        fail "self-ignoring .gitignore created with '*'"
    fi

    printf 'x\n' > "$repo/.superpowers/sdd/artifact.md"
    local status
    status="$(cd "$repo" && git status --porcelain)"
    if [[ -z "$status" ]]; then
        pass "workspace invisible to git status"
    else
        fail "workspace invisible to git status"
        echo "    status: $status"
    fi

    ( cd "$repo" && git add -A )
    local staged
    staged="$(cd "$repo" && git diff --cached --name-only)"
    if [[ -z "$staged" ]]; then
        pass "git add -A does not stage the workspace"
    else
        fail "git add -A does not stage the workspace"
        echo "    staged: $staged"
    fi

    canonical_task >"$repo/plan.md"

    local brief_out brief_path
    brief_out="$(cd "$repo" && "$SDD_SCRIPTS/task-brief" plan.md 1)"
    brief_path="$(printf '%s\n' "$brief_out" | sed -n 's/^\(.*task-1-brief\.md\): [0-9][0-9]* bytes$/\1/p')"
    case "$brief_path" in
        "$repo/.superpowers/sdd/"*) pass "task-brief writes its brief under the workspace" ;;
        *)
            fail "task-brief writes its brief under the workspace"
            echo "    got: $brief_path"
            ;;
    esac

    run_task_brief_cases
    run_sdd_state_cases

    local git_id=(-c user.email=t@example.com -c user.name=t -c commit.gpgsign=false)
    ( cd "$repo" \
        && git add plan.md \
        && git "${git_id[@]}" commit -qm c1 \
        && printf 'y\n' > f && git add f \
        && git "${git_id[@]}" commit -qm c2 )
    local rp_out rp_path
    rp_out="$(cd "$repo" && "$SDD_SCRIPTS/review-package" HEAD~1 HEAD --mode initial-task)"
    rp_path="$(printf '%s\n' "$rp_out" | sed -n '1p')"
    case "$rp_path" in
        .superpowers/sdd/*) [[ -f "$repo/$rp_path/manifest.json" ]] && pass "review-package writes its package under the workspace" ;;
        *)
            fail "review-package writes its diff under the workspace"
            echo "    got: $rp_path"
            ;;
    esac

    # --- Worktree isolation: a linked worktree resolves its own workspace ---
    local wt="$TEST_ROOT/wt"
    ( cd "$repo" && git worktree add -q "$wt" -b wt-feature )
    local wt_root wt_dir
    wt_root="$(cd "$wt" && git rev-parse --show-toplevel)"
    wt_dir="$(cd "$wt" && "$SDD_SCRIPTS/sdd-workspace")"
    if [[ "$wt_dir" == "$wt_root/.superpowers/sdd" && "$wt_dir" != "$dir" ]]; then
        pass "linked worktree resolves its own distinct workspace"
    else
        fail "linked worktree resolves its own distinct workspace"
        echo "    main: $dir"
        echo "    wt:   $wt_dir"
    fi

    printf 'y\n' > "$wt/.superpowers/sdd/artifact.md"
    local wt_status
    wt_status="$(cd "$wt" && git status --porcelain)"
    if [[ -z "$wt_status" ]]; then
        pass "worktree workspace invisible to git status"
    else
        fail "worktree workspace invisible to git status"
        echo "    status: $wt_status"
    fi

    echo ""
    if [[ "$FAILURES" -ne 0 ]]; then
        echo "FAILED: $FAILURES assertion(s)."
        exit 1
    fi
    echo "PASS"
}

main "$@"
