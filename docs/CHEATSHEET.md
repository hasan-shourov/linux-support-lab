# Cheat sheet: symptom to first command

Use this table when you meet a problem and do not know where to start. Run the first command, read the answer, then follow the scenario README for the full method.

| Symptom | First command to run | What it tells you | Scenario |
|---------|----------------------|-------------------|----------|
| IP address works, name does not | `ping -c 2 8.8.8.8` then `ping -c 2 google.com` | Network is fine, DNS is the problem | [01](../scenarios/01-dns-failure/README.md) |
| "Temporary failure in name resolution" | `cat /etc/resolv.conf` | Which DNS server the system uses | [01](../scenarios/01-dns-failure/README.md) |
| Local network works, internet does not | `ip route` | Where the default gateway points | [02](../scenarios/02-wrong-ip-gateway/README.md) |
| "Destination Host Unreachable" | `ip neigh` | Whether the next hop answers | [02](../scenarios/02-wrong-ip-gateway/README.md) |
| Site down, "Connection refused" (instant) | `systemctl status nginx` | Whether the service is running | [03](../scenarios/03-service-stopped/README.md) |
| Service will not start | `journalctl -u nginx -n 20` | The error the service logged | [03](../scenarios/03-service-stopped/README.md), [09](../scenarios/09-port-conflict/README.md) |
| Works on the server, times out from outside | `sudo ufw status numbered` | Firewall rules (also check `iptables -L -n`) | [04](../scenarios/04-firewall-blocking/README.md) |
| "Connection timed out" | `curl -v --max-time 5 http://SERVER-IP/` (from another machine) | Dropped packets, usually a firewall | [04](../scenarios/04-firewall-blocking/README.md) |
| "No space left on device" | `df -h` | Which filesystem is full | [05](../scenarios/05-disk-full/README.md) |
| Disk full, unknown cause | `sudo du -xh / --max-depth=2 \| sort -h \| tail` | Which folders are big | [05](../scenarios/05-disk-full/README.md) |
| Space not freed after deleting a file | `sudo lsof +L1` | Deleted files still held open | [05](../scenarios/05-disk-full/README.md) |
| HTTP 403 Forbidden | `curl -I http://localhost` then `sudo tail /var/log/nginx/error.log` | The status code and the reason | [06](../scenarios/06-permission-denied/README.md) |
| Permission denied somewhere on a path | `namei -l /path/to/file` | Permissions of every folder on the path | [06](../scenarios/06-permission-denied/README.md) |
| SSH key login refused | `sudo journalctl -u ssh -n 20` | The server's reason for refusing | [07](../scenarios/07-ssh-failure/README.md) |
| SSH "Permission denied (publickey)" | `ssh -vvv user@SERVER-IP` | Which keys were offered and refused | [07](../scenarios/07-ssh-failure/README.md) |
| Server is slow | `uptime` and `top` | Load average and the busiest process | [08](../scenarios/08-high-cpu/README.md) |
| Unknown process using CPU | `ps -eo pid,ppid,user,etime,args --sort=-%cpu \| head` | What it is, who started it, since when | [08](../scenarios/08-high-cpu/README.md) |
| "Address already in use" | `sudo ss -tulpn \| grep :80` | Which program owns the port | [09](../scenarios/09-port-conflict/README.md) |
| One website fails, others work | `getent ahostsv4 example.com` and `dig +short example.com` | What the system uses versus what DNS says | [10](../scenarios/10-bad-hosts-entry/README.md) |
| `dig` and `curl` disagree | `cat /etc/hosts` and `grep '^hosts' /etc/nsswitch.conf` | Local overrides of DNS | [10](../scenarios/10-bad-hosts-entry/README.md) |

## Three rules that save time

1. **Refused is not the same as timeout.** Refused (instant): the host is up and nothing listens. Timeout (waiting): packets are dropped, think firewall or routing.
2. **IP works, name does not: DNS.** Test an IP address and a name every time.
3. **Read the log before you guess.** `journalctl -u <service>` and `/var/log/` usually name the cause.
