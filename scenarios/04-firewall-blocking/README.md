# Scenario 04: Firewall blocking

**Difficulty:** Intermediate
**Estimated time:** 25 minutes

## Customer ticket

> **From:** Tom, marketing manager. **Priority:** High
>
> "Hi, our website works when we test on the server itself, but customers and my laptop only see a spinning page that never loads. It started after the security hardening yesterday."

## Symptoms

- From another machine, `curl` waits and then times out ("Connection timed out").
- On the server itself, `curl http://localhost` works fine.
- nginx is running and listening on port 80.

> **Important:** UFW always allows traffic on the loopback interface (`lo`), so `curl localhost` on the server still works. It cannot be used to prove that the firewall is fine. Always test from another machine, and check the rules with `ufw status numbered` and `iptables -L -n`.

## Step-by-step diagnosis

**Step 1. Test from the outside (your host machine, not the server).** Replace `SERVER-IP` with the server's address.

```bash
curl -v --max-time 5 http://SERVER-IP/
```

Example output:

```text
*   Trying 192.168.56.101:80...
* Connection timed out after 5001 milliseconds
* Closing connection
curl: (28) Connection timed out after 5001 milliseconds
```

The exact wording differs between curl versions. The clues that stay the same are the long wait, the words "timed out" (or "Timeout was reached") and exit code 28.

A timeout (waiting, no answer) is different from "Connection refused" (instant). A timeout usually means packets are silently dropped, which is what a firewall does.

**Step 2. On the server, check that the service is healthy.**

```bash
systemctl status nginx
sudo ss -tulpn | grep ':80'
curl -I http://localhost
```

Example output for the last two:

```text
tcp   LISTEN 0      511          0.0.0.0:80        0.0.0.0:*    users:(("nginx",pid=812,fd=5),("nginx",pid=811,fd=5))
HTTP/1.1 200 OK
```

nginx is fine and listening. The problem is between the client and the server.

**Step 3. Read the firewall rules.**

```bash
sudo ufw status verbose
sudo ufw status numbered
```

Example output:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
80/tcp                     DENY IN     Anywhere
22/tcp (OpenSSH)           ALLOW IN    Anywhere
80/tcp (v6)                DENY IN     Anywhere (v6)
22/tcp (OpenSSH (v6))      ALLOW IN    Anywhere (v6)
```

**Step 4. Look at the real packet filter underneath.**

```bash
sudo iptables -L -n | grep 'dpt:80'
```

Example output:

```text
DROP       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:80
```

## Root cause

UFW was active and had a rule that denies incoming traffic to port 80/tcp. The firewall dropped every connection to the website, while the service itself was healthy. The lab inserts the rule as rule 1 so that it wins over any existing allow rule, because UFW uses the first rule that matches.

## The fix

Manually:

```bash
sudo ufw delete deny 80/tcp
# Only if you want the site reachable on a firewall that stays on:
sudo ufw allow 80/tcp
```

With `fix.sh`: it deletes the deny rule, removes the SSH rule the lab added (unless it already existed before), puts back an allow rule for port 80 if one existed before, and runs `ufw disable` if UFW was inactive before the lab. The result is the exact original firewall state.

## Verification

From your host machine:

```bash
curl -I --max-time 5 http://SERVER-IP/
```

```text
[INFO] Deleting the deny rule for 80/tcp
[INFO] Deleting the SSH rule the lab added (OpenSSH)
[INFO] UFW was inactive before the lab, so turning it off again
[ OK ] The deny rule for 80/tcp is gone
[ OK ] UFW is back to its original state (active: no)
[PASS] Scenario 04-firewall-blocking is fixed. Everything is back to normal.
```

## Suggested reply to the customer

Hi Tom, I found why the site worked on the server but not for you. A security rule added yesterday was blocking visitors from reaching the website, even though the website itself was running fine. I removed that blocking rule and tested from outside the server: the site now loads for everyone. If you would like stricter security, I can allow only the web traffic you need instead of switching the protection off.

## Escalation notes

If a senior engineer had to take over, include:

- The result of the test from outside (`curl -v`, with the timeout) and from the server (`curl localhost`).
- `ufw status numbered` and `iptables -L -n` output taken during the problem.
- Who changed the firewall and when (`/var/log/ufw.log`, shell history, change tickets).
- Whether a cloud firewall or security group sits in front of the server as well.

## Key lessons

- Timeout means "dropped" (often a firewall). Refused means "nothing is listening".
- `curl localhost` does not test the firewall, because loopback traffic is always allowed.
- Test from the same place the customer is, and fix the rule instead of switching the firewall off.

## Related commands to learn

`ufw allow`, `ufw delete`, `ufw reload`, `nc -vz SERVER-IP 80`, `nmap -p 80 SERVER-IP`, `tcpdump -i any port 80`.
