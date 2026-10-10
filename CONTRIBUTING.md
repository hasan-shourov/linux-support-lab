
## Adding a scenario

1. Create `scenarios/NN-short-name/` with these four files:
   - `break.sh` and `fix.sh`: start from an existing scenario.
   - `hint.txt`: one line with the first command to run, no spoilers.
   - `README.md`: use the same sections and order as the other scenarios (title, difficulty and time, customer ticket, symptoms, diagnosis with "Example output", root cause, the fix, verification, suggested reply, escalation notes, three key lessons, related commands).
2. Source `lib/common.sh`. Use `begin_break` or `begin_fix`, `note_set` and `note_get`, `backup_file`, `set_active` and `finish_fix` instead of writing your own checks.
3. Make every action honor `--dry-run`: use `run`, `write_file` and `append_line` for anything that changes the system.
4. Keep the number in the folder name unique. `./lab.sh list` reads the difficulty from the README line `**Difficulty:** ...`.
5. Add a row to the table in the root README and to `docs/CHEATSHEET.md`.

## Style

- `#!/usr/bin/env bash` and `set -euo pipefail` in every script.
- Quote every variable. Four spaces for indentation (see `.editorconfig`).
- Zero shellcheck warnings. Do not hide a warning without a comment that explains why.
- Example output in the docs must match what the scripts really print.

## Checks before you open a pull request

```bash
make lint                                  # bash -n and shellcheck -x
./lab.sh break N --dry-run                 # for your new scenario
sudo ./tests/smoke_test.sh                 # on a VM with systemd
```

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```text
feat: add scenario 11 (expired certificate)
fix: restore the original UFW state when it was inactive
docs: explain nsswitch order in scenario 10
```
