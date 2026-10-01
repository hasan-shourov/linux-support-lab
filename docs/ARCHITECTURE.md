# Architecture

This document explains how the lab is built: the design, how state is tracked, and the safety model. You do not need it to use the lab. It is here for contributors and for anyone who wants to see how the scripts work.

## Design goals

1. **Safe by default.** Every break can be undone, and the riskiest ones undo themselves.
2. **Teach the method, not the trick.** The scripts only create the problem. The learning is in the diagnosis and the write-up.
3. **Small and readable.** Plain Bash, one shared library, the same four files per scenario.
4. **Honest output.** Messages in the documentation match what the scripts print.

## Layout

```text
lab.sh                 CLI: list, break, fix, status, hint, solution, reset
setup.sh               installs packages, writes the demo page, starts nginx
lib/common.sh          everything shared (sourced, never run on its own)
scenarios/NN-name/
  break.sh             creates the problem
  fix.sh               restores the original state and verifies it
  hint.txt             the first command to run
  README.md            the full write-up (also what "solution" prints)
tests/smoke_test.sh    dry-runs all ten and runs a full cycle for 03, 06, 09, 10
```

## How a command flows

```text
./lab.sh break 3 --yes
   |
   |  parses flags, exports LAB_YES=1 / LAB_DRY_RUN=1
   v
scenarios/03-service-stopped/break.sh
   |
   |  begin_break: OS check, systemd check, root check,
   |               refuse if another scenario is active, ask for confirmation
   |  note_set / backup_file: record the original state
   |  set_active: write active.state            <- from here on, a failure can be undone
   |  arm_failure_notice: explain how to recover if the script stops early
   |  ... the actual change ...
   v
finish_break: print the result and the customer ticket
```

`fix` mirrors it: `begin_fix`, restore from the backups, `check` each result, then `finish_fix` prints `PASS` and cleans up, or prints `FAIL` and keeps the backups so you can try again.

`lab.sh` passes `--yes` and `--dry-run` to the scenario scripts as the environment variables `LAB_YES=1` and `LAB_DRY_RUN=1`. Scenario scripts can also be run directly. They enforce the same rules themselves.

## State tracking

| Path | Content |
|------|---------|
| `/var/lib/troubleshooting-lab/active.state` | Two lines: `scenario=<id>` and `started=<UTC time>`. Its presence means a scenario is active. |
| `/var/lib/troubleshooting-lab/workers.pid` | PIDs of the CPU workers (scenario 08) |
| `/var/lib/troubleshooting-lab/listener.pid` | PID of the rogue port listener (scenario 09) |
| `/var/lib/troubleshooting-lab/lab-revert-NN.pid` | PID of the fallback auto-revert job, when `systemd-run` was not available |
| `/var/backups/troubleshooting-lab/<scenario>/` | File copies and `note.<key>` files with the original state |

The state directory is world-readable (mode 755), so `list` and `status` work without root. The backup directory is private (mode 700).

`set_active` is called after the backups are written and before anything is changed. That order matters: if the break stops halfway, the lab already knows that a scenario is active and has everything it needs to undo it.

## Backups and notes

- `backup_file <path>` copies a file once. A second call keeps the first copy, so re-running a break can never replace the real original with an already broken file.
- `restore_file <path>` writes the content back into the same file instead of replacing it. This keeps the inode, which matters for bind-mounted files such as `/etc/hosts` and `/etc/resolv.conf` in containers.
- `note_set` and `note_get` store small facts that are not whole files: the old file owner and mode, the original route, whether UFW was active.
- A successful `fix` removes the backups of that scenario, so the next break starts from a fresh record.

## Safety model

| Risk | Protection |
|------|------------|
| Running on the wrong machine | Warning and confirmation before every break (`--yes` skips it) |
| Two problems at once | Only one scenario can be active. `break` refuses and names the one to fix |
| Running without privileges or on another OS | Root required (except read-only commands and `--dry-run`). Ubuntu and Debian only |
| Missing systemd | Scenarios 02, 03, 04, 07 and 09 print a clear message and exit with code 2 |
| Locking yourself out (network, SSH) | Scenario 02 and 07 schedule their own revert before they break anything. Scenario 04 allows SSH before enabling UFW. Scenario 07 validates with `sshd -t` and shows a "keep a second session open" warning |
| Filling the disk | Scenario 05 always leaves 1 GB free and refuses to create a file under 100 MB |
| Killing the wrong process | Scenarios 08 and 09 only stop PIDs they recorded, and only if the command line still matches |
| Losing the original state | Backups are made first and never overwritten. If a fix fails, backups are kept |
| A script stopping halfway | Break prints how to recover (`./lab.sh reset`). Fix prints `FAIL` and keeps the backups |
| Breaking the machine "by accident" in tests | Only 03, 06, 09 and 10 run for real in the smoke test. All other scenarios are dry-run only |

### Dry run

Every action that changes the system goes through `run`, `write_file` or `append_line`, which print `[DRY-RUN] ...` instead of acting when `--dry-run` is set. Read-only commands still run (to read the current route, for example). In dry-run mode the OS and systemd checks only warn, and root is not required.

### Auto-revert (scenarios 02 and 07)

`schedule_revert <seconds> <unit> <command>` runs `systemd-run --on-active=<seconds>s --unit=<unit> <path>/fix.sh` with `LAB_YES=1`. If `systemd-run` is not available it starts a background job (`nohup`, `sleep`, `exec`) and stores its PID. `cancel_revert` stops the timer or the job. It skips the PID of the current process, because the fallback job runs `fix.sh` under the same PID.

The delay is `LAB_REVERT_SECONDS` (default 120 for scenario 02 and 600 for scenario 07).

## Environment variables

| Variable | Default | Meaning |
|----------|---------|---------|
| `LAB_YES` | `0` | Skip the confirmation (set by `--yes`) |
| `LAB_DRY_RUN` | `0` | Print actions without running them (set by `--dry-run`) |
| `LAB_REVERT_SECONDS` | 120 (02), 600 (07) | Delay before the automatic revert |
| `LAB_DISK_MB` | `5120` | Wanted size of the big file in scenario 05 |
| `LAB_STATE_DIR` | `/var/lib/troubleshooting-lab` | Where the active state and PID files live |
| `LAB_BACKUP_DIR` | `/var/backups/troubleshooting-lab` | Where the backups live |
| `NO_COLOR` | unset | Turn colors off. Colors are also off when the output is not a terminal |

## Conventions

- Every script starts with `#!/usr/bin/env bash` and `set -euo pipefail`, quotes all variables and passes `shellcheck -x` with zero warnings.
- Because of `pipefail`, a `cmd | grep -q` can fail when `grep` exits early. The scripts capture the output in a variable and use a here-string instead.
- Verification uses `check <description> <function>`. It counts failures, and `finish_fix` turns the count into `PASS` or `FAIL`.
- Scenario scripts find `lib/common.sh` relative to their own location, so the repository works from any folder.

## Adding a scenario

See [CONTRIBUTING.md](../CONTRIBUTING.md).
