# Scenario 09: Port conflict

**Difficulty:** Intermediate
**Estimated time:** 25 minutes

The break stops nginx and starts `python3 -m http.server 80 --bind 0.0.0.0` in the background, then tries to start nginx so that it fails and logs the bind error. For safety, the lab serves an empty folder (`--directory`), so the rogue server never exposes real files. Its PID is saved in `/var/lib/troubleshooting-lab/listener.pid`.

## Customer ticket

> **From:** Karim, web developer. **Priority:** Urgent
>
> "We restarted the web server after an update and now it will not come back. The site is down. The restart command just says it failed. This is urgent."

## Symptoms

- `systemctl start nginx` or `restart` fails.
- The website does not load, or loads something strange (an empty directory listing).
- Something is already listening on port 80.

## Step-by-step diagnosis

**Step 1. What does systemd say?**

```bash
systemctl status nginx
```

Example output:

```text
× nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: failed (Result: exit-code) since Thu 2026-10-01 10:40:34 UTC; 4s ago
    Process: 2346 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=1/FAILURE)
```

**Step 2. Read the reason in the logs.**

```bash
journalctl -u nginx -n 20 --no-pager
sudo tail -n 3 /var/log/nginx/error.log
```

Example output:

```text
nginx[2346]: nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)
nginx[2346]: nginx: [emerg] still could not bind()
systemd[1]: nginx.service: Control process exited, code=exited, status=1/FAILURE
systemd[1]: Failed to start nginx.service - A high performance web server and a reverse proxy server.
```

`Address already in use` is the key phrase: another program has the port.

**Step 3. Who has port 80?**

```bash
sudo ss -tulpn | grep ':80'
sudo lsof -i :80
```

Example output:

```text
tcp   LISTEN 0      5            0.0.0.0:80        0.0.0.0:*    users:(("python3",pid=122,fd=3))

COMMAND PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
python3 122 root    3u  IPv4  41234      0t0  TCP *:http (LISTEN)
```

**Step 4. Find out what that process is before you touch it.**

```bash
ps -o pid,ppid,user,lstart,args -p 122
```

It is a Python test web server, not a service you want in production.

## Root cause

A stray `python3 -m http.server` was already using port 80, so nginx could not bind to it and refused to start. Two programs cannot listen on the same address and port.

## The fix

Manually:

```bash
sudo kill 122                    # use the PID you found
sudo systemctl reset-failed nginx
sudo systemctl start nginx
```

With `fix.sh`: it stops the recorded PID (only after checking that it is the Python listener), waits for the port to be free, removes the empty web folder, runs `reset-failed`, starts nginx and verifies that nginx now owns port 80.

## Verification

```bash
systemctl status nginx
sudo ss -tulpn | grep ':80'
curl -I http://localhost
```

```text
[INFO] Stopping the program that is using port 80
[INFO] Stopped 1 recorded process(es).
[INFO] Starting nginx
[ OK ] nginx is running
[ OK ] nginx is the program listening on port 80
[ OK ] The site answers on http://localhost
[PASS] Scenario 09-port-conflict is fixed. Everything is back to normal.
```

## Suggested reply to the customer

Hi Karim, your site is up again. The web server could not start because a leftover test program was already using the address that websites use. I stopped that test program, started the web server normally and checked that the site answers. If this was a test someone started on purpose, please tell me, so we can give it a different address next time.

## Escalation notes

If a senior engineer had to take over, include:

- The nginx error text (`bind() ... Address already in use`) and the time.
- The output of `ss -tulpn | grep :80` and `ps` for the process that holds the port.
- Who started that process and how (user, parent process, start time).
- Whether you stopped it, and whether it should be moved to another port or removed for good.

## Key lessons

- `Address already in use` means two programs want the same port. Find the owner with `ss` or `lsof`.
- Identify a process before you stop it. It may belong to someone else.
- After you clear the cause, run `systemctl reset-failed` so the service state is clean.

## Related commands to learn

`ss -ltnp`, `lsof -i`, `fuser 80/tcp`, `systemctl reset-failed`, `nginx -t`, `journalctl -xeu nginx`.
