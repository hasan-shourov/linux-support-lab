# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project uses [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-01

### Added
- `lab.sh` command line tool: `list`, `break`, `fix`, `status`, `hint`, `solution`, `reset`.
- Shared library `lib/common.sh` with logging, root and OS checks, dry-run support,
  backups, state tracking and scheduled auto-revert.
- Ten troubleshooting scenarios: DNS failure, wrong gateway, stopped service,
  firewall block, full disk, permission denied, SSH failure, high CPU,
  port conflict and a bad hosts entry.
- A README for every scenario with a customer ticket, diagnosis steps, root cause,
  fix, suggested customer reply and escalation notes.
- Documentation: architecture, cheat sheet, troubleshooting method and ticket template.
- `tests/smoke_test.sh` and a GitHub Actions workflow that runs `bash -n` and `shellcheck`.
