# linux-troubleshooting-lab

A hands-on lab where you break an Ubuntu server in 10 ways, diagnose each problem with standard tools, fix it, and write it up like a support ticket.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![lint](https://github.com/hasan-shourov/linux-support-lab/actions/workflows/lint.yml/badge.svg)](https://github.com/hasan-shourov/linux-support-lab/actions/workflows/lint.yml)
[![Platform: Ubuntu](https://img.shields.io/badge/platform-Ubuntu%2022.04%20%7C%2024.04-E95420)](https://ubuntu.com/)


DNS, networking, systemd, UFW, disk usage, permissions, SSH, processes, ports, the hosts file and ticket writing.

> **WARNING: Run this lab only in a disposable virtual machine or container.**
> The scenarios deliberately change DNS settings, routes, firewall rules, file permissions, SSH settings and running services. Never run them on a machine you care about, on a shared server or in production.

## Prerequisites

- Ubuntu 22.04 or 24.04 in a VM (VirtualBox is fine) or a container. Debian also works.
- A user with `sudo` rights, and internet access for the first setup.
- Basic comfort with a terminal.
- A normal VM with systemd is needed for scenarios 02, 03, 04, 07 and 09. Without systemd (common in containers) these exit with code 2 and a clear message. Scenarios 01, 05, 06, 08 and 10 work without systemd.
- A second machine (your host PC) is useful for scenarios 04 and 07, which are best tested from the outside.

## Quick start

```bash
git clone https://github.com/hasan-shourov/linux-support-lab.git linux-troubleshooting-lab
cd linux-troubleshooting-lab
sudo ./setup.sh
./lab.sh list
sudo ./lab.sh break 3
# diagnose: systemctl status nginx, journalctl -u nginx, ss -tulpn, curl -I localhost
sudo ./lab.sh fix 3
```

(The folder name after the URL is your choice. This README uses `linux-troubleshooting-lab`.)

Stuck? `./lab.sh hint 3` shows the first command to try. `./lab.sh solution 3` shows the full write-up, which is a spoiler. `sudo ./lab.sh reset` puts everything back whatever state you are in.

## The 10 scenarios

| No. | Scenario | Difficulty | Skills |
|-----|----------|------------|--------|
| 01 | [DNS failure](scenarios/01-dns-failure/README.md) | Beginner | resolv.conf, resolvectl, dig, IP vs name testing |
| 02 | [Wrong gateway](scenarios/02-wrong-ip-gateway/README.md) | Intermediate | routing table, ip route, ip neigh, traceroute |
| 03 | [Service stopped](scenarios/03-service-stopped/README.md) | Beginner | systemctl, journalctl, connection refused |
| 04 | [Firewall blocking](scenarios/04-firewall-blocking/README.md) | Intermediate | UFW, iptables, timeout vs refused, testing from outside |
| 05 | [Disk full](scenarios/05-disk-full/README.md) | Beginner | df, du, find, lsof +L1 |
| 06 | [Permission denied](scenarios/06-permission-denied/README.md) | Beginner | HTTP 403, chmod, chown, namei, error logs |
| 07 | [SSH failure](scenarios/07-ssh-failure/README.md) | Intermediate | ssh -vvv, StrictModes, auth.log, sshd -T |
| 08 | [High CPU](scenarios/08-high-cpu/README.md) | Beginner | top, ps, load average, nice, kill |
| 09 | [Port conflict](scenarios/09-port-conflict/README.md) | Intermediate | ss, lsof, bind errors, systemd failures |
| 10 | [Bad hosts entry](scenarios/10-bad-hosts-entry/README.md) | Beginner | /etc/hosts, nsswitch, getent, why dig can disagree |

Every scenario README follows the same ticket-style structure: customer ticket, symptoms, step-by-step diagnosis with example output, root cause, the fix, verification, a suggested reply to the customer, escalation notes, key lessons and related commands. The method behind it is in [docs/TROUBLESHOOTING-METHOD.md](docs/TROUBLESHOOTING-METHOD.md), a one-page symptom lookup is in [docs/CHEATSHEET.md](docs/CHEATSHEET.md), and the blank ticket is in [docs/TICKET-TEMPLATE.md](docs/TICKET-TEMPLATE.md).

## Example session

The lab messages below are what the scripts really print. The commands in between are typical diagnosis steps.

```text
$ ./lab.sh list

No.  Scenario               Difficulty    Status
---  ---------------------- ------------- ------
01   dns-failure            Beginner      OK
02   wrong-ip-gateway       Intermediate  OK
03   service-stopped        Beginner      OK
04   firewall-blocking      Intermediate  OK
05   disk-full              Beginner      OK
06   permission-denied      Beginner      OK
07   ssh-failure            Intermediate  OK
08   high-cpu               Beginner      OK
09   port-conflict          Intermediate  OK
10   bad-hosts-entry        Beginner      OK

[INFO] No scenario is active. Start one with: ./lab.sh break 3

$ sudo ./lab.sh break 3

[WARN] This stops the nginx web server, so the website goes offline.
[WARN] Run this lab only in a disposable VM or container.
Break scenario 03-service-stopped now? [y/N] y
[ OK ] nginx is stopped and the site no longer answers
[ OK ] Scenario 03-service-stopped is now active. The website should be down now.

Customer ticket
  "Our company website is down! Visitors see an error page and nobody changed anything on our side. This is urgent, we are losing orders."

Diagnose it like a support engineer. Need a nudge? ./lab.sh hint 3
Done? Put it back with: ./lab.sh fix 3

$ curl -I http://localhost
curl: (7) Failed to connect to localhost port 80 after 0 ms: Couldn't connect to server

$ systemctl status nginx
○ nginx.service - A high performance web server and a reverse proxy server
     Active: inactive (dead) since Thu 2026-10-01 10:20:11 UTC; 12s ago

$ sudo systemctl start nginx
$ sudo ./lab.sh fix 3
[INFO] Starting nginx
[ OK ] nginx is running
[ OK ] The site answers on http://localhost
[PASS] Scenario 03-service-stopped is fixed. Everything is back to normal.
```

Then write the ticket summary with [docs/TICKET-TEMPLATE.md](docs/TICKET-TEMPLATE.md).

## Project structure

```text
linux-troubleshooting-lab/
  README.md
  LICENSE
  CHANGELOG.md
  CONTRIBUTING.md
  .gitignore
  .editorconfig
  Makefile                       help, setup, lint, test, list, reset
  lab.sh                         the command line tool
  setup.sh                       installs the tools and a demo web page
  lib/
    common.sh                    logging, checks, backups, state, auto-revert
  scenarios/
    01-dns-failure/              break.sh, fix.sh, hint.txt, README.md
    02-wrong-ip-gateway/         (same four files in every folder)
    03-service-stopped/
    04-firewall-blocking/
    05-disk-full/
    06-permission-denied/
    07-ssh-failure/
    08-high-cpu/
    09-port-conflict/
    10-bad-hosts-entry/
  docs/
    ARCHITECTURE.md              design, state tracking, safety model
    CHEATSHEET.md                symptom -> first command to run
    TROUBLESHOOTING-METHOD.md    observe, hypothesize, test, fix, verify, document
    TICKET-TEMPLATE.md           support ticket template
  tests/
    smoke_test.sh                break -> verify -> fix -> verify
  .github/workflows/
    lint.yml                     bash -n and shellcheck on every script
```

## How it works

- **One active scenario at a time.** `break` refuses to start while another scenario is active and tells you which one to fix first.
- **State tracking.** The active scenario is recorded in `/var/lib/troubleshooting-lab/active.state`. `./lab.sh list` and `./lab.sh status` read it.
- **Backups.** Before a break changes anything, it saves the original state (file copies and notes) in `/var/backups/troubleshooting-lab/`. A second `break` never overwrites the first backup.
- **Fix and verify.** `fix` restores from those backups, runs checks and prints `PASS` or `FAIL`. If a step stops unexpectedly, the backups are kept so you can try again.
- **Auto-revert.** Scenarios 02 (network) and 07 (SSH) can lock you out, so they schedule their own fix before they break anything. It runs after 120 seconds (02) or 600 seconds (07). Change the delay with `LAB_REVERT_SECONDS`. It uses `systemd-run` and falls back to a background job.
- **Dry run.** `./lab.sh break N --dry-run` prints every action without running it and needs no root.

More detail is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Safety notes

- Disposable VM or container only.
- Root is required to change anything. Only `--help`, `--version`, `list`, `status`, `hint`, `solution` and `--dry-run` work without root, and none of them change anything.
- The OS must be Ubuntu or Debian. Anything else is refused (only warned about in `--dry-run`).
- You must confirm every break unless you pass `--yes`.
- Scenario 04 allows SSH in UFW before it enables the firewall, so you do not lock yourself out.
- Scenario 05 always leaves at least 1 GB free and refuses to run when less than 100 MB would be used.
- Scenario 07 asks you to keep a second SSH session open, validates the SSH configuration with `sshd -t` before it reloads, and reverts itself.
- Scenario 08 stops after 30 minutes on its own and `fix` kills only the PIDs the lab recorded.

Choices made where the specification was open (the safest option each time):

- Scenario 02 keeps the original route metric, so the bad route replaces the old one instead of sitting next to it.
- Scenario 04 inserts the deny rule as rule 1, so it works even if a port 80 allow rule already exists, and `fix` restores that allow rule.
- Scenario 09 serves an empty folder, so the temporary Python server never exposes real files.
- Scenario 10 verifies with `getent ahostsv4`, because plain `getent hosts` asks for IPv6 first and can hide the IPv4 hosts entry.
- `setup.sh` also installs `iproute2`, `traceroute`, `python3` and `openssh-server`, which scenarios 02, 07 and 09 use.

## Testing

`make lint` runs `bash -n` and `shellcheck -x` on every script, and the same check runs on every push in GitHub Actions. `tests/smoke_test.sh` dry-runs all ten scenarios, and on a machine with systemd it runs the full break, verify, fix, verify cycle for scenarios 03, 06, 09 and 10. Scenarios 01, 02, 04, 05, 07 and 08 change the network, firewall, disk, SSH or CPU of the machine, so they are not part of the automatic test. Try them in a VM and see their README files.

## Skills demonstrated

For recruiters hiring Support Engineers:

- **Linux administration:** systemd, networking, DNS, UFW and iptables, permissions, SSH, processes, disk and log analysis.
- **Systematic troubleshooting:** every scenario follows observe, hypothesize, test, fix, verify, document.
- **Root cause analysis:** each write-up separates the symptom from the root cause and the fix.
- **Bash scripting:** idempotent scripts with backups, state tracking, dry-run mode, safe auto-revert and clear error handling.
- **Written customer communication:** every scenario includes a plain-English reply to a non-technical customer.
- **Ticket documentation:** a ticket template and escalation notes for every scenario.
- **CI with shellcheck:** a GitHub Actions workflow keeps every script lint-clean.

## Roadmap

- More scenarios: expired TLS certificate, out of inodes, failing cron job, wrong time zone or NTP drift, full `/var/log`.
- A `--random` mode that picks a scenario without telling you which one.
- A container image with systemd for easier practice.
- Optional timing and a small self-check quiz after each fix.

## Contributing

Ideas and new scenarios are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## License

MIT. See [LICENSE](LICENSE).

Built by Mehedi (https://github.com/hasan-shourov)
