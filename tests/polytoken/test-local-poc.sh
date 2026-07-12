#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER="$REPO_ROOT/scripts/install-polytoken-poc.sh"
HOOK="$REPO_ROOT/hooks/session-start-polytoken"
TEST_ROOT="$(mktemp -d)"
CONFIG_DIR="$TEST_ROOT/config"
DEFAULT_CONFIG_DIR="$TEST_ROOT/xdg/polytoken"
COLLISION_CONFIG_DIR="$TEST_ROOT/collision-config"
INVALID_HOOKS_CONFIG_DIR="$TEST_ROOT/invalid-hooks-config"
MIGRATION_CONFIG_DIR="$TEST_ROOT/migration-config"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$CONFIG_DIR"
printf '%s\n' '[{"name":"unrelated-hook","event":"session_start","handler":{"bash":"exit 0"}}]' > "$CONFIG_DIR/hooks.json"

"$INSTALLER" install --config-dir "$CONFIG_DIR"
"$INSTALLER" install --config-dir "$CONFIG_DIR"
XDG_CONFIG_HOME="$TEST_ROOT/xdg" "$INSTALLER" install
[[ -d "$DEFAULT_CONFIG_DIR/skills/brainstorming" && ! -L "$DEFAULT_CONFIG_DIR/skills/brainstorming" ]] || fail "default XDG config directory was not used"
XDG_CONFIG_HOME="$TEST_ROOT/xdg" "$INSTALLER" uninstall
[[ ! -e "$DEFAULT_CONFIG_DIR/skills/brainstorming" ]] || fail "default XDG install was not removed"

for skill in "$REPO_ROOT"/skills/*/SKILL.md; do
  name="$(basename "$(dirname "$skill")")"
  [[ -d "$CONFIG_DIR/skills/$name" && ! -L "$CONFIG_DIR/skills/$name" ]] || fail "skill was not copied: $name"
  [[ -f "$CONFIG_DIR/skills/$name/.superpowers-polytoken-poc" ]] || fail "missing ownership marker: $name"
  cmp "$skill" "$CONFIG_DIR/skills/$name/SKILL.md" >/dev/null || fail "copied skill differs: $name"
  polytoken validate skill "$CONFIG_DIR/skills/$name/SKILL.md" >/dev/null
done
[[ -x "$CONFIG_DIR/superpowers/session-start-polytoken" ]] || fail "hook runtime was not copied"
[[ -f "$CONFIG_DIR/superpowers/.superpowers-polytoken-poc" ]] || fail "hook runtime ownership marker missing"

printf 'stale copy\n' > "$CONFIG_DIR/skills/brainstorming/SKILL.md"
"$INSTALLER" install --config-dir "$CONFIG_DIR"
cmp "$REPO_ROOT/skills/brainstorming/SKILL.md" "$CONFIG_DIR/skills/brainstorming/SKILL.md" >/dev/null || fail "reinstall did not refresh copied skill"

python3 - "$CONFIG_DIR/hooks.json" <<'PY'
import json
import pathlib
import sys

hooks = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
names = [entry.get("name") for entry in hooks if isinstance(entry, dict)]
assert names.count("unrelated-hook") == 1, names
assert names.count("superpowers-session-start") == 1, names
assert names.count("superpowers-post-compaction") == 1, names
PY

handler_command="$(python3 - "$CONFIG_DIR/hooks.json" <<'PY'
import json
import pathlib
import sys
hooks = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print(next(entry["handler"]["bash"] for entry in hooks if isinstance(entry, dict) and entry.get("name") == "superpowers-session-start"))
PY
)"
handler_output="$(POLYTOKEN_HOOK_EVENT=session_start bash -c "$handler_command")"
python3 - "$handler_output" <<'PY'
import json
import sys
payload = json.loads(sys.argv[1])
assert payload["outcome"] == "allow", payload
assert "additional_context" in payload, payload
PY

assert_hook() {
  local event="$1"
  local field="$2"
  local output
  output="$(POLYTOKEN_HOOK_EVENT="$event" "$HOOK")"
  python3 - "$field" "$output" <<'PY'
import json
import sys

field = sys.argv[1]
payload = json.loads(sys.argv[2])
assert payload["outcome"] == "allow", payload
assert set(payload) == {"outcome", field}, payload
context = payload[field]
for marker in [
    "If you think there is even a 1% chance a skill might apply",
    "Polytoken Tool Mapping",
    "translate `superpowers:<name>` to `<name>`",
]:
    assert marker in context, marker
PY
}

assert_hook session_start additional_context
assert_hook post_compaction append_to_output

mkdir -p "$COLLISION_CONFIG_DIR/skills/writing-skills"
printf 'do not replace\n' > "$COLLISION_CONFIG_DIR/skills/writing-skills/owner.txt"
if "$INSTALLER" install --config-dir "$COLLISION_CONFIG_DIR" >/dev/null 2>&1; then
  fail "installer accepted an existing skill collision"
fi
[[ -f "$COLLISION_CONFIG_DIR/skills/writing-skills/owner.txt" ]] || fail "collision content was removed"
[[ ! -e "$COLLISION_CONFIG_DIR/skills/brainstorming" ]] || fail "collision left a partial install"
[[ ! -e "$COLLISION_CONFIG_DIR/hooks.json" ]] || fail "collision modified hooks"

mkdir -p "$INVALID_HOOKS_CONFIG_DIR"
printf 'not json\n' > "$INVALID_HOOKS_CONFIG_DIR/hooks.json"
if "$INSTALLER" install --config-dir "$INVALID_HOOKS_CONFIG_DIR" >/dev/null 2>&1; then
  fail "installer accepted invalid hooks JSON"
fi
[[ ! -e "$INVALID_HOOKS_CONFIG_DIR/skills/brainstorming" ]] || fail "invalid hooks left a partial install"
[[ "$(cat "$INVALID_HOOKS_CONFIG_DIR/hooks.json")" == "not json" ]] || fail "invalid hooks file was modified"

mkdir -p "$MIGRATION_CONFIG_DIR/skills"
ln -s "$REPO_ROOT/skills/brainstorming" "$MIGRATION_CONFIG_DIR/skills/brainstorming"
"$INSTALLER" install --config-dir "$MIGRATION_CONFIG_DIR"
[[ -d "$MIGRATION_CONFIG_DIR/skills/brainstorming" && ! -L "$MIGRATION_CONFIG_DIR/skills/brainstorming" ]] || fail "legacy symlink was not migrated to a copy"
"$INSTALLER" uninstall --config-dir "$MIGRATION_CONFIG_DIR"

"$INSTALLER" uninstall --config-dir "$CONFIG_DIR"
python3 - "$CONFIG_DIR/hooks.json" <<'PY'
import json
import pathlib
import sys
hooks = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
names = [entry.get("name") for entry in hooks if isinstance(entry, dict)]
assert names == ["unrelated-hook"], names
assert not any(isinstance(entry, dict) and entry.get("name", "").startswith("superpowers-") for entry in hooks)
PY

for source in "$REPO_ROOT"/skills/*; do
  [[ ! -e "$CONFIG_DIR/skills/$(basename "$source")" ]] || fail "skill remained after uninstall: $(basename "$source")"
done

printf 'Polytoken local POC tests passed\n'
