# Scenario 02: Wrong gateway

**Difficulty:** Intermediate
**Estimated time:** 20 minutes

The break changes the routing table at runtime only (no netplan file is touched) and reverts itself after `LAB_REVERT_SECONDS` (default 120 seconds). A reboot also removes it.

## Customer ticket

> **From:** Daniel, release manager. **Priority:** High
>
> "Hello, the server suddenly has no internet. We can still reach other machines in the office network, but updates and external websites time out. This is blocking a release."

## Symptoms

- External addresses do not answer: `ping 8.8.8.8` shows 100% loss or "Destination Host Unreachable".
- Machines in the same local network still answer.
- Name lookups fail too (DNS servers are outside the local network), but that is a side effect, not the cause.

## Step-by-step diagnosis

**Step 1. Check whether the problem is local or beyond the gateway.**

```bash
ping -c 2 8.8.8.8
ping -c 2 <another-machine-in-your-local-network>
```

**Step 2. Read the routing table. The line that starts with `default` tells the server where to send everything that is not local.**

```bash
ip route
ip addr
```

Example output:

```text
default via 10.0.2.253 dev enp0s3 onlink metric 100
10.0.2.0/24 dev enp0s3 proto kernel scope link src 10.0.2.15
```

Check the gateway address. Compare it with what the network should use (look at `cat /etc/netplan/*.yaml` or `networkctl status`).

**Step 3. Test the gateway itself.**

```bash
ping -c 2 10.0.2.253
ip neigh show 10.0.2.253
```

Example output:

```text
From 10.0.2.15 icmp_seq=1 Destination Host Unreachable
From 10.0.2.15 icmp_seq=2 Destination Host Unreachable
10.0.2.253 dev enp0s3  FAILED
```

`FAILED` means nobody answered the "who has this address?" question: no device owns that address.

**Step 4. See where packets stop.**

```bash
traceroute -n -m 3 8.8.8.8
```

Example output:

```text
traceroute to 8.8.8.8 (8.8.8.8), 3 hops max, 60 byte packets
 1  10.0.2.15  3005.4 ms !H  3005.3 ms !H  3005.2 ms !H
```

The very first hop fails, so the problem is the first step out of this server.

## Root cause

The default route pointed to `10.0.2.253`, an address that no device uses. Local traffic still worked because the local network has its own route, but everything else was sent to a gateway that does not exist.

## The fix

Manually, point the default route back to the real gateway:

```bash
sudo ip route replace default via 10.0.2.2 dev enp0s3
```

(Use your own gateway and interface name.) This is a runtime change. If the correct gateway is also wrong in the netplan file, fix it there and run `sudo netplan apply`.

With `fix.sh`: it cancels the pending auto-revert timer, deletes any route to the bad gateway, and runs `ip route replace` with the exact default route saved before the break. The auto-revert runs the same script, so waiting does the same job.

## Verification

```bash
ip route
ping -c 2 8.8.8.8
```

```text
[INFO] Restoring the default route: default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100
[ OK ] The default route points to 10.0.2.2 again
[ OK ] The gateway 10.0.2.2 answers ping
[PASS] Scenario 02-wrong-ip-gateway is fixed. Everything is back to normal.
```

## Suggested reply to the customer

Hi Daniel, I found the cause. The server was sending all outside traffic to an address that does not belong to any device, like posting letters to a house that does not exist. Traffic inside the office network was not affected, which is why it looked odd. I pointed it back to the correct router and confirmed that updates and websites work again. Please tell me if anyone changed network settings today so we can make sure it does not come back.

## Escalation notes

If a senior engineer had to take over, include:

- Output of `ip route`, `ip addr` and `ip neigh` taken while the problem was present.
- The gateway you expected and where you found it (netplan file, DHCP lease, network diagram).
- Whether the machine is reachable over the local network, and whether other servers in the same subnet are affected.
- The time it started and any recent network or DHCP changes.

## Key lessons

- "Local works, internet does not" points to the default gateway.
- `ip route` shows where traffic goes. `ip neigh` shows whether the next hop answers at the network level.
- A change that only lives in the kernel (runtime) disappears on reboot. A change in netplan is permanent.

## Related commands to learn

`ip route get 8.8.8.8`, `ip neigh`, `networkctl status`, `netplan get`, `mtr`, `tcpdump -i any icmp`.
