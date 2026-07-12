# Polytoken Local Proof of Concept

This is an experimental, local-only Superpowers integration for Polytoken. It proves native skill discovery, automatic bootstrap injection, and post-compaction reinjection. It is **not** a production installer and does not yet satisfy Superpowers' upstream requirement that integrations use the harness's own package mechanism.

## Requirements

- Polytoken 0.5.0 or newer
- Bash
- Python 3
- A local clone of this repository for installation and updates

## Install

Run:

```bash
scripts/install-polytoken-poc.sh install
```

The installer uses `${XDG_CONFIG_HOME:-$HOME/.config}/polytoken`, matching Polytoken's default user/global config root. To confirm the root used by your installed Polytoken version, run `EDITOR=echo polytoken config edit --user`; the printed config file's parent directory is the user config root. That command may create a timestamped backup of an existing config file.

For a non-default installation, pass the root explicitly:

```bash
scripts/install-polytoken-poc.sh install --config-dir /path/to/polytoken-user-config
```

The installer:

1. Copies each existing `skills/*` directory into `<config-dir>/skills/`.
2. Copies the session hook into `<config-dir>/superpowers/`.
3. Preserves unrelated hook entries in `<config-dir>/hooks.json`.
4. Adds `superpowers-session-start` and `superpowers-post-compaction` hooks.

Copied skill directories contain a `.superpowers-polytoken-poc` ownership marker. Reinstall refreshes only marked copies and migrates symlinks created by older versions of this POC; it refuses to overwrite unrelated skill directories.

Restart Polytoken or use its configuration reload action after installation.

## Verify

Validate discovery:

```bash
polytoken validate skill brainstorming
polytoken validate skill using-superpowers
```

For the required clean-session behavior test, open a fresh Polytoken session and send exactly:

> Let's make a react todo list

The agent should invoke the `brainstorming` skill before writing or scaffolding code.

Also compact the session and confirm that subsequent work still checks and invokes relevant skills.

## Update

Pull changes in this clone, rerun the installer to refresh its owned copies, and reload Polytoken:

```bash
git pull
scripts/install-polytoken-poc.sh install
```

## Uninstall

```bash
scripts/install-polytoken-poc.sh uninstall
```

Pass the same `--config-dir` used for installation when overriding the default. Uninstall removes only ownership-marked copies, legacy symlinks that point into this clone, the owned hook runtime, and the two hooks named above. It preserves unrelated skills and hooks.

## Known limitations

- Polytoken currently has no documented plugin/package installation mechanism, so this POC intentionally edits the selected config directory.
- Updates are not automatic; rerun the installer after changing the repository clone.
- Globally installed companion scripts can still be subject to Polytoken's normal file and shell permissions when invoked by the model.
- Polytoken skill names are directory basenames. The bootstrap maps `superpowers:<name>` references to the native `<name>` skill.
- This POC installs no facets, subagents, or themes; Polytoken's native general-purpose subagent and facets provide the required primitives.
