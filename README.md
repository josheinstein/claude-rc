# claude-rc

Boot-time [Claude Code Remote Control](https://code.claude.com/docs/en/remote-control)
sessions, one per directory, supervised by systemd user units.

You list directories in a plain text file; every entry becomes a
`claude rc` session that appears in claude.ai/code under the directory's
basename, starts at boot, restarts on failure, and is stopped when you remove
it from the list.

## How it works

| Piece | Role |
| --- | --- |
| `~/.config/claude-rc/sessions.conf` | One directory per line. `~` is expanded, `#` comments allowed. |
| `bin/claude-rc-ctl` | The controller. `sync` reads the config and starts/stops instances to match. `add`/`remove` edit the config for you. |
| `bin/claude-rc-add` | One-liner wrapper: register the current directory and start its session. |
| `systemd/claude-rc.service` | Oneshot unit enabled at boot; runs `claude-rc-ctl sync` (and `stop-all` on stop). |
| `systemd/claude-rc@.service` | Template unit; instance `%i` runs `claude rc --name %i` in that entry's directory. |
| `bin/claude-rc-interrupted` | Helper: lists sessions that a reboot cut off mid-turn, with `claude --resume` commands. |

Instances run through a login shell (`bash -lic`) so the session sees the same
`PATH` and environment as an interactive terminal (nvm, conda, `~/.local/bin`).
`claude rc` is started with `--permission-mode auto --no-create-session-in-dir`.

Exit code 78 from the controller means "bad config" (directory missing,
untrusted, or removed from the list) and the unit does not retry it. Other
failures restart after 15 s, at most 5 times in 5 minutes.

## Install

```bash
git clone <this repo> ~/repos/claude-rc
~/repos/claude-rc/install.sh
```

The installer copies the scripts to `~/.local/bin`, the units to
`~/.config/systemd/user`, seeds `sessions.conf` from the example if absent,
runs `daemon-reload`, enables `claude-rc.service`, and enables lingering so
the sessions run without anyone logged in.

Requirements: Claude Code CLI on the login-shell `PATH`, `python3`, a systemd
user manager. You must be logged in to Claude Code already.

## Usage

```bash
cd ~/repos/some-project
claude-rc-add                 # add cwd to the config and start it

claude-rc-ctl list            # dirs, trust status, running state
claude-rc-ctl sync            # apply the config after editing it by hand
claude-rc-ctl remove [dir]    # drop an entry and stop its session
claude-rc-ctl logs [name]     # follow the journal
claude-rc-ctl restart [name]
claude-rc-interrupted         # what did the last reboot interrupt?
```

## Workspace trust (the one manual step)

`claude rc` refuses to start in a directory that has not been trusted, and
trust is per exact directory: trusting `~/repos` does **not** cover
`~/repos/foo`. Before a new entry will start, run `claude` in that directory
once interactively and accept the trust dialog. `claude-rc-ctl list` shows
`NOT TRUSTED` for entries that still need this, and `sync` skips them with a
message rather than letting the unit fail.

## Re-creating by hand

If you would rather not use the installer, the whole thing is:

1. `bin/*` → `~/.local/bin/` (executable)
2. `systemd/*` → `~/.config/systemd/user/`
3. `sessions.conf.example` → `~/.config/claude-rc/sessions.conf`, edited
4. `systemctl --user daemon-reload && systemctl --user enable --now claude-rc.service`
5. `sudo loginctl enable-linger $USER`
