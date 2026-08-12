#!/usr/bin/env bash
# Test: subagent-driven-development skill
# Verifies that the skill is loaded and follows correct workflow
#
# No drill coverage: this test asks the agent to *describe* SDD (string-
# matches its verbal explanation against expected keywords like
# "self-review", "skeptical", "worktree", "Step 1", "loop"). Drill scenarios
# test behavior (real subagent dispatch, plan-following, review loops),
# not description-recall. Kept by design.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

CLAUDE_PROMPT_TIMEOUT="${CLAUDE_PROMPT_TIMEOUT:-90}"

echo "=== Test: subagent-driven-development skill ==="
echo ""

# Test 0: Brainstorming must preserve the post-approval execution fork.
# This is a static regression guard for the handoff behavior; it must run before
# any model-backed checks so a missing fork fails fast and deterministically.
echo "Test 0: Brainstorming execution fork..."
BRAINSTORMING_SKILL="$SCRIPT_DIR/../../skills/brainstorming/SKILL.md"
flowchart_fork_line=$(grep -nF '"Execution Fork:' "$BRAINSTORMING_SKILL" | head -1 | cut -d: -f1 || true)
flowchart_approved_line=$(grep -nF '"User reviews doc?" -> "Execution Fork:' "$BRAINSTORMING_SKILL" | head -1 | cut -d: -f1 || true)
flowchart_inline_line=$(grep -nF '"Execution Fork:' "$BRAINSTORMING_SKILL" | grep -F 'Implement inline' | head -1 | cut -d: -f1 || true)
flowchart_subagent_line=$(grep -nF '"Execution Fork:' "$BRAINSTORMING_SKILL" | grep -F 'Delegate checklist' | head -1 | cut -d: -f1 || true)
checklist_choice_line=$(grep -nF '9. **Choose execution path**' "$BRAINSTORMING_SKILL" | head -1 | cut -d: -f1 || true)
checklist_execute_line=$(grep -nF '10. **Execute the chosen path**' "$BRAINSTORMING_SKILL" | head -1 | cut -d: -f1 || true)
handoff_line=$(grep -nF "present this choice before doing any implementation" "$BRAINSTORMING_SKILL" | head -1 | cut -d: -f1 || true)
inline_line=$(grep -nF "**1. Lightweight / inline**" "$BRAINSTORMING_SKILL" | head -1 | cut -d: -f1 || true)
subagent_line=$(grep -nF "**2. Subagent workflow**" "$BRAINSTORMING_SKILL" | head -1 | cut -d: -f1 || true)
choice_line=$(grep -nF "Which path do you want?" "$BRAINSTORMING_SKILL" | head -1 | cut -d: -f1 || true)
review_line=$(grep -nF "User Review Gate" "$BRAINSTORMING_SKILL" | head -1 | cut -d: -f1 || true)
implementation_line=$(grep -nF "**Implementation paths:**" "$BRAINSTORMING_SKILL" | head -1 | cut -d: -f1 || true)
if [[ -n "$flowchart_fork_line" && -n "$flowchart_approved_line" && -n "$flowchart_inline_line" && -n "$flowchart_subagent_line" && -n "$checklist_choice_line" && -n "$checklist_execute_line" && -n "$handoff_line" && -n "$inline_line" && -n "$subagent_line" && -n "$choice_line" && -n "$review_line" && -n "$implementation_line" && "$checklist_choice_line" -lt "$checklist_execute_line" && "$review_line" -lt "$implementation_line" && "$implementation_line" -lt "$inline_line" && "$inline_line" -lt "$subagent_line" && "$subagent_line" -lt "$choice_line" ]]; then
    echo "  [PASS] Execution fork is explicit and follows document review"
else
    echo "  [FAIL] Brainstorming silently selects an execution path"
    exit 1
fi

echo ""

# Test 1: Bounded task-authoring contract
# Keep each recipe assertion tied to its owning skill so a matching phrase in
# another contract cannot mask a missing requirement.
echo "Test 1: Bounded task-authoring contract..."
BRAINSTORMING_AUTHORING="$SCRIPT_DIR/../../skills/brainstorming/SKILL.md"
WRITING_PLANS_AUTHORING="$SCRIPT_DIR/../../skills/writing-plans/SKILL.md"
SKILL_FILE="$SCRIPT_DIR/../../skills/subagent-driven-development/SKILL.md"
IMPLEMENTER_PROMPT="$SCRIPT_DIR/../../skills/subagent-driven-development/implementer-prompt.md"
REVIEWER_PROMPT="$SCRIPT_DIR/../../skills/subagent-driven-development/task-reviewer-prompt.md"
FINAL_REVIEW_PROMPT="$SCRIPT_DIR/../../skills/requesting-code-review/code-reviewer.md"
INTEGRATION_TEST="$SCRIPT_DIR/test-subagent-driven-development-integration.sh"
assert_canonical_recipe() {
    local file=$1 label=$2 required
    for required in \
        '### Task 1: Implement bounded parser behavior' \
        '**Files:**' \
        '- Modify: `src/parser.py`' \
        '- Test: `tests/test_parser.py`' \
        '**Focused behavior:**' \
        '**Test intent:**' \
        '**Inherited interfaces:**' \
        '- None' \
        '**Out of scope:**' \
        '- Unrelated Markdown extensions' \
        '**Done when:**' \
        '**Review intent:**' \
        '**Cohesion override:**'; do
        if ! grep -qF -- "$required" "$file"; then
            echo "  [FAIL] $label missing canonical recipe text: $required"
            return 1
        fi
    done
    echo "  [PASS] $label has the bounded task recipe"
}
assert_canonical_recipe "$BRAINSTORMING_AUTHORING" "Brainstorming"
assert_canonical_recipe "$WRITING_PLANS_AUTHORING" "Writing plans"

for required in \
    'independently testable behavioral slice' \
    'Split before dispatch' \
    'More than four production files' \
    'multiple package roots' \
    'refactor-plus-behavior' \
    'non-empty cohesion override'; do
    if ! grep -qF -- "$required" "$WRITING_PLANS_AUTHORING"; then
        echo "  [FAIL] Writing plans missing boundary guidance: $required"
        exit 1
    fi
done
for required in \
    'independently testable behavioral slice' \
    'split it before dispatch' \
    'More than four production files' \
    'multiple package roots' \
    'refactor-plus-behavior' \
    'non-empty **Cohesion override**'; do
    if ! grep -qF -- "$required" "$BRAINSTORMING_AUTHORING"; then
        echo "  [FAIL] Brainstorming missing boundary guidance: $required"
        exit 1
    fi
done
echo "  [PASS] Task boundaries are warning-threshold based"

# These stale phrases are checked against the files that own the guidance.
if grep -qF -- 'full task text' "$SKILL_FILE"; then
    echo "  [FAIL] SDD skill retains stale handoff guidance: full task text"
    exit 1
fi
if grep -qF -- 'Read your task brief first:' "$IMPLEMENTER_PROMPT"; then
    echo "  [FAIL] Implementer prompt retains stale brief wording"
    exit 1
fi
if grep -qF -- 'a broad whole-branch review happens separately' "$REVIEWER_PROMPT"; then
    echo "  [FAIL] Task reviewer prompt retains stale review wording"
    exit 1
fi
if grep -qF -- 'code quality standards before it cascades' "$FINAL_REVIEW_PROMPT"; then
    echo "  [FAIL] Final reviewer prompt retains stale review wording"
    exit 1
fi
echo "  [PASS] Workflow handoffs use scoped artifact paths"

EXPECTED_TASK_MODE_TEXT='Review this task'"'"'s implementation. This is an independent task-scoped gate, not a merge review — a fresh integration-focused final review happens separately. Use review mode `initial-task` or `incremental-rereview` exactly as supplied by the controller.'
EXPECTED_FINAL_MODE_TEXT='Review the completed work against its requirements and integration-focused quality standards before it cascades into more work. Use review mode `final-integration` or `final-incremental-rereview` exactly as supplied by the controller; this is one fresh branch-level review, not a tiered review.'
validate_mode_prompt() {
    local prompt=$1 expected=$2 allowed_a=$3 allowed_b=$4 declaration_count
    declaration_count=$(awk -v expected="$expected" '{ line=$0; sub(/^[[:space:]]+/, "", line); if (line == expected) count++ } END { print count + 0 }' "$prompt")
    [[ "$declaration_count" -eq 1 ]] || return 1
    grep -qF -- "\`$allowed_a\`" "$prompt" && grep -qF -- "\`$allowed_b\`" "$prompt"
}
if ! validate_mode_prompt "$REVIEWER_PROMPT" "$EXPECTED_TASK_MODE_TEXT" initial-task incremental-rereview || \
   ! validate_mode_prompt "$FINAL_REVIEW_PROMPT" "$EXPECTED_FINAL_MODE_TEXT" final-integration final-incremental-rereview || \
   grep -qE '^ *Use review mode `[^`]+` or `[^`]+` exactly as supplied\.?$' "$SKILL_FILE" "$IMPLEMENTER_PROMPT"; then
    echo "  [FAIL] Review mode set or scoped semantics are incomplete"
    exit 1
fi
if ! grep -qF 'Review modes are exactly `initial-task`, `incremental-rereview`, `final-integration`, and `final-incremental-rereview`.' "$SKILL_FILE"; then
    echo "  [FAIL] Review mode set is incomplete"
    exit 1
fi
echo "  [PASS] Review modes are exactly the four allowed modes with scoped semantics"

if grep -qF 'Controller provides: <directly or by file>' "$INTEGRATION_TEST"; then
    echo "  [FAIL] Integration fixture still requests pasted task text"
    exit 1
else
    echo "  [PASS] Integration fixture uses path-based dispatch"
fi

if grep -qF 'test-subagent-driven-development.sh' "$SCRIPT_DIR/run-skill-tests.sh"; then
    echo "  [PASS] SDD contract test is registered"
else
    echo "  [FAIL] SDD contract test is not registered"
    exit 1
fi

echo ""

# Test 2: Static workflow contract
# Each contract phrase is asserted against the file that owns it.
echo "Test 2: Workflow contract..."
for required in \
    'Orient → RED/GREEN → Verify → Report' \
    'max 20 grep' \
    'one concrete concept per search' \
    'index-first complete-shard navigation'; do
    if ! grep -qF -- "$required" "$SKILL_FILE"; then
        echo "  [FAIL] SDD skill missing workflow contract: $required"
        exit 1
    fi
done
echo "  [PASS] SDD skill owns bounded workflow guidance"

echo ""

# Test 3: Verify skill can be loaded
echo "Test 3: Skill loading..."

output=$(run_claude "What is the subagent-driven-development skill? Describe its key steps briefly." "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "subagent-driven-development\|Subagent-Driven Development\|Subagent Driven" "Skill is recognized"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Load Plan\|read.*plan\|extract.*tasks" "Mentions loading plan"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 4: Verify skill describes correct workflow order
echo "Test 4: Workflow ordering..."

output=$(run_claude "In the subagent-driven-development skill, what comes first: spec compliance review or code quality review? Answer using exactly this structure:
First: <review type>
Second: <review type>" "$CLAUDE_PROMPT_TIMEOUT")

if assert_order "$output" "First:.*spec.*compliance" "Second:.*code.*quality" "Spec compliance before code quality"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 5: Verify self-review is mentioned
echo "Test 5: Self-review requirement..."

output=$(run_claude "Does the subagent-driven-development skill require implementers to self-review before handoff, and can self-review replace the external reviews? Answer using exactly this structure:
Self-review required: <yes or no>
Self-review replaces external review: <yes or no>" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "Self-review required:.*yes" "Mentions self-review"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Self-review replaces external review:.*no" "Self-review does not replace external review"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 6: Verify plan is read once
echo "Test 6: Plan reading efficiency..."

output=$(run_claude "In subagent-driven-development, how many times should the controller read the plan file? When does this happen?" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "once\|one time\|single" "Read plan once"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Step 1\|beginning\|start\|Load Plan" "Read at beginning"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 7: Verify spec compliance reviewer is skeptical
echo "Test 7: Spec compliance reviewer mindset..."

output=$(run_claude "What is the spec compliance reviewer's attitude toward the implementer's report in subagent-driven-development?" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "not trust\|don't trust\|skeptical\|verify.*independently\|suspiciously" "Reviewer is skeptical"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "read.*code\|inspect.*code\|verify.*code" "Reviewer reads code"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 8: Verify review loops
echo "Test 8: Review loop requirements..."

output=$(run_claude "In subagent-driven-development, what happens if a reviewer finds issues? Is it a one-time review or a loop?" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "loop\|again\|repeat\|until.*approved\|until.*compliant" "Review loops mentioned"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "implementer.*fix\|fix.*issues" "Implementer fixes issues"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 9: Verify full task text is provided
echo "Test 9: Task context provision..."

output=$(run_claude "In subagent-driven-development, how does the controller provide task information to the implementer subagent? Answer using exactly this structure:
Controller provides: <directly or by file>
Implementer must read plan file: <yes or no>" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "provide.*directly\|full.*text\|paste\|include.*prompt" "Provides text directly"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Implementer must read plan file:.*no" "Doesn't make subagent read file"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 10: Verify worktree requirement
echo "Test 10: Worktree requirement..."

output=$(run_claude "What workflow skills are required before using subagent-driven-development? List any prerequisites or required skills." "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "using-git-worktrees\|worktree" "Mentions worktree requirement"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 11: Verify main branch warning
echo "Test 11: Main branch red flag..."

output=$(run_claude "In subagent-driven-development, is it okay to start implementation directly on the main branch?" "$CLAUDE_PROMPT_TIMEOUT")

if assert_contains "$output" "worktree\|feature.*branch\|not.*main\|never.*main\|avoid.*main\|don't.*main\|consent\|permission" "Warns against main branch"; then
    : # pass
else
    exit 1
fi

echo ""

echo "=== All subagent-driven-development skill tests passed ==="
