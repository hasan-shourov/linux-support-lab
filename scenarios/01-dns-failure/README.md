# Scenario 01: DNS failure

**Difficulty:** Beginner
**Estimated time:** 15 minutes

## Customer ticket

> **From:** Priya, operations lead. **Priority:** High
>
> "Hi support, our server can reach the internet by IP address but nothing can be opened by name. Package updates fail too and we have a customer demo this afternoon."

## Symptoms

- `ping 8.8.8.8` works, but `ping google.com` fails after a delay.
- `apt update` fails with "Temporary failure resolving".
- Websites cannot be opened by name from the server.

## Step-by-step diagnosis

**Step 1. Separate the network from the name lookup.** If an IP address works and a name does not, the network is fine and the problem is DNS.

```bash
ping -c 2 8.8.8.8
ping -c 2 google.com
```

Example output:

```text
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time=12.4 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=117 time=11.9 ms
...
ping: google.com: Temporary failure in name resolution
```

**Step 2. Look at which DNS server the system is told to use.**

```bash
cat /etc/resolv.conf
ls -l /etc/resolv.conf
```

Example output:

```text
# Written by troubleshooting-lab (scenario 01). Undo with: ./lab.sh fix 1
nameserver 192.0.2.53
-rw-r--r-- 1 root root 96 Oct  1 10:12 /etc/resolv.conf
```

Two clues here. The server `192.0.2.53` looks unusual, and on a normal Ubuntu server this file is a symlink (`lrwxrwxrwx`), not a regular file.

**Step 3. Ask the resolver service what it thinks.**

```bash
resolvectl status
resolvectl query google.com
getent hosts google.com
```

`resolvectl` talks to systemd-resolved directly and may still look healthy, while `getent` follows `/etc/resolv.conf` like most programs do. When the two disagree, programs are not using the resolver you expect.

**Step 4. Test the DNS server itself.**

```bash
dig google.com
dig @8.8.8.8 google.com
nslookup google.com
```

Example output for the first command:

```text
;; communications error to 192.0.2.53#53: timed out
;; communications error to 192.0.2.53#53: timed out
;; communications error to 192.0.2.53#53: timed out

; <<>> DiG 9.18.39-0ubuntu0.24.04.7-Ubuntu <<>> google.com
;; global options: +cmd
;; no servers could be reached
```

`dig @8.8.8.8 google.com` returns an answer, which proves that DNS works and only the configured server is wrong.

## Root cause

`/etc/resolv.conf` pointed to `192.0.2.53`, a DNS server that does not exist. Every name lookup waited for an answer that never came.

## The fix

Manually, put the original symlink back (this is the Ubuntu default) or set a working server:

```bash
sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
# or, as a quick test only:
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

With `fix.sh`: it reads what `break.sh` recorded. If the file was a symlink, it removes the regular file and recreates the exact same symlink. If the file was a regular file (or a bind mount in a container), it writes the original content back in place. It then flushes the resolver cache.

## Verification

```bash
ls -l /etc/resolv.conf
ping -c 2 google.com
```

`./lab.sh fix 1` checks this for you:

```text
[INFO] Restoring the symlink /etc/resolv.conf -> ../run/systemd/resolve/stub-resolv.conf
[ OK ] /etc/resolv.conf is a symlink to ../run/systemd/resolve/stub-resolv.conf again
[ OK ] /etc/resolv.conf no longer lists 192.0.2.53
[ OK ] Name lookup works again
[PASS] Scenario 01-dns-failure is fixed. Everything is back to normal.
```

## Suggested reply to the customer

Hi Priya, thanks for the details. The server could reach the internet, but it had been given a wrong address for its "phone book" that turns website names into numbers, so every name lookup failed. I corrected that setting and tested: names now resolve and updates run again. Nothing else was changed. I will keep an eye on it until your demo is finished.

## Escalation notes

If a senior engineer had to take over, include:

- Hostname, OS version and the time the problem started.
- What works (`ping 8.8.8.8`) and what fails (`ping google.com`, `apt update`), with the exact error text.
- The content of `/etc/resolv.conf` and whether it is a symlink (`ls -l`).
- The output of `resolvectl status` and of `dig @8.8.8.8 google.com`.
- What you already tried, and whether anyone changed the network or DNS settings recently.

## Key lessons

- Test an IP address and a name separately. It splits "network problem" from "DNS problem" in one minute.
- `/etc/resolv.conf` decides what most programs use, even if `resolvectl` looks healthy.
- Always check whether a config file is a symlink before editing it, and put it back exactly as it was.

## Related commands to learn

`resolvectl query`, `resolvectl flush-caches`, `host`, `dig +trace`, `getent hosts`, `ls -l`, `readlink`.
