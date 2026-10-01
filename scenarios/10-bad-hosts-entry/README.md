# Scenario 10: Bad hosts entry

**Difficulty:** Beginner
**Estimated time:** 20 minutes

The break appends this line to `/etc/hosts`:

```text
203.0.113.10 example.com # troubleshooting-lab
```

## Customer ticket

> **From:** Nadia, data analyst. **Priority:** Low
>
> "Hello, one website (example.com) will not open from our server. Other websites work fine. A colleague says it opens from his laptop. Can you take a look? It is not blocking us, but it is annoying."

## Symptoms

- `curl` and `ping` to `example.com` hang or time out.
- Other websites work, so DNS and the network are fine in general.
- `dig example.com` shows a normal, working address.

## Step-by-step diagnosis

**Step 1. See which address the system really uses.**

```bash
ping -c 2 example.com
```

Example output:

```text
PING example.com (203.0.113.10) 56(84) bytes of data.

--- example.com ping statistics ---
2 packets transmitted, 0 received, 100% packet loss, time 1030ms
```

**Step 2. Compare with what DNS says.**

```bash
dig +short example.com
```

Example output:

```text
172.66.147.243
104.20.23.154
```

Different addresses. The system is not asking DNS, or it would get the second answer. Note that `dig` talks to the DNS server directly and ignores `/etc/hosts`. That is why it can look healthy while `curl` and `ping` fail. This is the main teaching point of this scenario.

**Step 3. Ask the system the way programs do.**

```bash
getent ahostsv4 example.com
```

Example output:

```text
203.0.113.10    STREAM example.com
203.0.113.10    DGRAM
203.0.113.10    RAW
```

`getent ahosts` uses the same lookup as `curl` and `ping`. Plain `getent hosts example.com` can mislead on a machine with IPv6 DNS: it asks for IPv6 first, so it may show an IPv6 answer and hide the IPv4 entry.

**Step 4. Find where the address comes from.**

```bash
grep '^hosts' /etc/nsswitch.conf
cat /etc/hosts
```

Example output:

```text
hosts:          files dns
127.0.0.1 localhost
127.0.1.1 web01
203.0.113.10 example.com # troubleshooting-lab
```

`files dns` means: look in `/etc/hosts` first, and ask DNS only if the file has no answer. The last line of the file is the culprit.

## Root cause

A manual entry in `/etc/hosts` mapped `example.com` to `203.0.113.10`, which does not serve the site. Because the hosts file is checked before DNS, it overrode the correct answer for this server only.

## The fix

Manually, edit the file and remove only that line:

```bash
sudo nano /etc/hosts
```

With `fix.sh`: it removes only the lines that carry the marker comment `# troubleshooting-lab` and leaves the rest of the file untouched. It writes the file in place, because `/etc/hosts` is a bind mount in many containers and cannot be replaced with `mv`. A copy of the original file is kept as a backup until the fix passes.

## Verification

```bash
getent ahostsv4 example.com
curl -I http://example.com
```

```text
[INFO] Removing the lines marked '# troubleshooting-lab' from /etc/hosts
[ OK ] No lab lines are left in /etc/hosts
[ OK ] example.com no longer resolves to 203.0.113.10
[PASS] Scenario 10-bad-hosts-entry is fixed. Everything is back to normal.
```

## Suggested reply to the customer

Hi Nadia, I found why only that one website failed on our server. Someone had added a manual address for it in a settings file on the server, and that address was wrong, so the server went to the wrong place. Your colleague's laptop did not have that entry, which is why it worked there. I removed the wrong line and the website now opens correctly from the server.

## Escalation notes

If a senior engineer had to take over, include:

- The result of `getent ahostsv4` (what the system uses) next to `dig +short` (what DNS says) for the same name.
- The full content of `/etc/hosts` and the line of `/etc/nsswitch.conf` that starts with `hosts`.
- Who added the line and when (file modification time, shell history, change tickets).
- Whether other names are overridden, and whether any configuration management tool rewrites the file.

## Key lessons

- `dig` ignores `/etc/hosts`. `curl`, `ping` and most programs do not. When they disagree, suspect the hosts file.
- The order in `/etc/nsswitch.conf` (`files dns`) decides which source wins.
- Use `getent ahosts` to see what programs see. Plain `getent hosts` can show IPv6 first.

## Related commands to learn

`getent ahosts`, `host`, `nslookup`, `curl -v`, `resolvectl query`, `cat /etc/nsswitch.conf`.
