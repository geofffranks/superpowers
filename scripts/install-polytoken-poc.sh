#!/usr/bin/env bash
# Install or uninstall the local Superpowers proof of concept for Polytoken.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/install-polytoken-poc.sh <install|uninstall> [--config-dir DIR]

This proof of concept copies Superpowers skills into a Polytoken user config
and merges two named hooks into hooks.json. It preserves unrelated hooks.

By default, DIR is ${XDG_CONFIG_HOME:-$HOME/.config}/polytoken. Use
--config-dir only when Polytoken uses a non-default user config directory.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[[ $# -ge 1 ]] || { usage >&2; exit 2; }
action="$1"
shift
config_dir="${XDG_CONFIG_HOME:-${HOME:?HOME must be set}/.config}/polytoken"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-dir)
      [[ $# -ge 2 ]] || die "--config-dir requires a directory"
      config_dir="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ "$action" == "install" || "$action" == "uninstall" ]] || die "action must be install or uninstall"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
config_dir="$(mkdir -p "$config_dir" && cd "$config_dir" && pwd)"
skills_dir="$config_dir/skills"
hooks_file="$config_dir/hooks.json"
runtime_dir="$config_dir/superpowers"
hook_script="$runtime_dir/session-start-polytoken"
# $HOME-relative so the hook resolves on host AND in containers.
if [[ "$config_dir" == "$HOME"/* ]]; then
  hook_script="\$HOME/${config_dir#"$HOME"/}/superpowers/session-start-polytoken"
fi
source_hook_script="$REPO_ROOT/hooks/session-start-polytoken"
ownership_marker=".superpowers-polytoken-poc"

validate_hooks() {
  python3 - "$hooks_file" <<'PY'
import json
import pathlib
import sys

hooks_path = pathlib.Path(sys.argv[1])
if hooks_path.exists():
    try:
        hooks = json.loads(hooks_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"error: invalid JSON in {hooks_path}: {exc}")
    if not isinstance(hooks, list):
        raise SystemExit(f"error: {hooks_path} must contain a JSON array")
PY
}

merge_hooks() {
  local mode="$1"
  python3 - "$hooks_file" "$hook_script" "$mode" <<'PY'
import json
import pathlib
import shlex
import sys

hooks_path = pathlib.Path(sys.argv[1])
hook_script = sys.argv[2]
mode = sys.argv[3]
names = {"superpowers-session-start", "superpowers-post-compaction"}

if hooks_path.exists():
    try:
        hooks = json.loads(hooks_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"error: invalid JSON in {hooks_path}: {exc}")
    if not isinstance(hooks, list):
        raise SystemExit(f"error: {hooks_path} must contain a JSON array")
else:
    hooks = []

hooks = [entry for entry in hooks if not (isinstance(entry, dict) and entry.get("name") in names)]
if mode == "install":
    hooks.extend([
        {
            "name": "superpowers-session-start",
            "event": "session_start",
            "handler": {"bash": f'exec bash "{hook_script}"'},
        },
        {
            "name": "superpowers-post-compaction",
            "event": "post_compaction",
            "handler": {"bash": f'exec bash "{hook_script}"'},
        },
    ])

hooks_path.write_text(json.dumps(hooks, indent=2) + "\n", encoding="utf-8")
PY
}

command -v python3 >/dev/null 2>&1 || die "python3 is required"

if [[ "$action" == "install" ]]; then
  [[ -x "$source_hook_script" ]] || die "$source_hook_script must be executable"
  validate_hooks

  # Preflight every destination so a collision cannot leave a partial install.
  for source in "$REPO_ROOT"/skills/*; do
    [[ -d "$source" && -f "$source/SKILL.md" ]] || continue
    destination="$skills_dir/$(basename "$source")"
    if [[ -L "$destination" ]]; then
      current="$(readlink "$destination")"
      [[ "$current" == "$source" ]] || die "skill collision: $destination points to $current"
    elif [[ -e "$destination" && ! -f "$destination/$ownership_marker" ]]; then
      die "skill collision: $destination exists and is not owned by this installer"
    fi
  done
  if [[ -e "$runtime_dir" && ! -f "$runtime_dir/$ownership_marker" ]]; then
    die "runtime collision: $runtime_dir exists and is not owned by this installer"
  fi

  mkdir -p "$skills_dir"
  for source in "$REPO_ROOT"/skills/*; do
    [[ -d "$source" && -f "$source/SKILL.md" ]] || continue
    destination="$skills_dir/$(basename "$source")"
    staging="$(mktemp -d "$skills_dir/.superpowers-copy.XXXXXX")"
    cp -R "$source"/. "$staging"/
    : > "$staging/$ownership_marker"
    if [[ -L "$destination" || -f "$destination/$ownership_marker" ]]; then
      rm -rf "$destination"
    fi
    mv "$staging" "$destination"
  done

  runtime_staging="$(mktemp -d "$config_dir/.superpowers-runtime.XXXXXX")"
  cp "$source_hook_script" "$runtime_staging/session-start-polytoken"
  chmod +x "$runtime_staging/session-start-polytoken"
  : > "$runtime_staging/$ownership_marker"
  [[ ! -e "$runtime_dir" ]] || rm -rf "$runtime_dir"
  mv "$runtime_staging" "$runtime_dir"

  merge_hooks install
  printf 'Installed Superpowers Polytoken POC in %s\n' "$config_dir"
else
  if [[ -d "$skills_dir" ]]; then
    for destination in "$skills_dir"/*; do
      if [[ -d "$destination" && -f "$destination/$ownership_marker" ]]; then
        rm -rf "$destination"
      elif [[ -L "$destination" ]]; then
        source="$REPO_ROOT/skills/$(basename "$destination")"
        [[ "$(readlink "$destination")" != "$source" ]] || rm "$destination"
      fi
    done
  fi
  merge_hooks uninstall
  if [[ -d "$runtime_dir" && -f "$runtime_dir/$ownership_marker" ]]; then
    rm -rf "$runtime_dir"
  fi
  printf 'Uninstalled Superpowers Polytoken POC from %s\n' "$config_dir"
fi
