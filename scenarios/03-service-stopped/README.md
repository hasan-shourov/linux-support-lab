# Scenario 03: Service stopped

**Difficulty:** Beginner
**Estimated time:** 10 minutes

## Customer ticket

> **From:** Maria, shop owner. **Priority:** Urgent
>
> "Our company website is down! Visitors see an error page and nobody changed anything on our side. This is urgent, we are losing orders."

## Symptoms

- The website does not load. The browser says it cannot connect.
- `curl` fails immediately (it does not wait): "Connection refused".
- The server itself still answers ping and SSH.

## Step-by-step diagnosis

**Step 1. Reproduce the problem.**

```bash
curl -I http://localhost
```

Example output:

```text
curl: (7) Failed to connect to localhost port 80 after 0 ms: Couldn't connect to server
```

"Connection refused" arrives instantly. It means the machine is reachable but nothing is listening on that port.

**Step 2. Ask systemd about the service.**

```bash
systemctl status nginx
```

Example output:

```text
○ nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: inactive (dead) since Thu 2026-10-01 10:20:11 UTC; 12s ago
```

**Step 3. Read the logs to learn why it stopped.**

```bash
journalctl -u nginx -n 10 --no-pager
```

Example output:

```text
Oct 01 10:20:11 web01 systemd[1]: Stopping nginx.service - A high performance web server and a reverse proxy server...
Oct 01 10:20:11 web01 systemd[1]: nginx.service: Deactivated successfully.
Oct 01 10:20:11 web01 systemd[1]: Stopped nginx.service - A high performance web server and a reverse proxy server.
```

A clean "Deactivated successfully" means someone stopped it. It did not crash.

**Step 4. Confirm that nothing listens on port 80.**

```bash
sudo ss -tulpn | grep ':80'
```

There is no output. The port is not in use.

## Root cause

The nginx service was stopped, so nothing was listening on port 80.

## The fix

Manually:

```bash
sudo systemctl start nginx
sudo systemctl enable nginx   # makes sure it also starts after a reboot
```

With `fix.sh`: it runs `systemctl start nginx` and then checks that the service is active and that `curl http://localhost` succeeds.

## Verification

```bash
systemctl is-active nginx
curl -I http://localhost
```

```text
[INFO] Starting nginx
[ OK ] nginx is running
[ OK ] The site answers on http://localhost
[PASS] Scenario 03-service-stopped is fixed. Everything is back to normal.
```

## Suggested reply to the customer

Hi Maria, your website is back online. The program that serves the site had been switched off on the server, so visitors could not connect. I started it again and tested the site from the server. I am now checking who or what stopped it, and I will tell you if I find a reason so it does not happen again.

## Escalation notes

If a senior engineer had to take over, include:

- The exact time the site went down, and the output of `systemctl status nginx`.
- The journal lines around that time (`journalctl -u nginx --since "30 min ago"`).
- Whether any deployment, update or cron job ran near that time.
- Whether the service is enabled for boot (`systemctl is-enabled nginx`).

## Key lessons

- "Connection refused" (instant) means the host is up but no program is listening.
- `systemctl status` shows the state, and `journalctl -u` shows the story behind it.
- Fix the service, then also ask why it stopped.

## Related commands to learn

`systemctl restart`, `systemctl is-enabled`, `journalctl -f`, `nginx -t`, `ss -tulpn`, `curl -v`.
