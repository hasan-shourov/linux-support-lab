# Scenario 08: High CPU

**Difficulty:** Beginner
**Estimated time:** 15 minutes

The break starts one worker per CPU core with `nice -n 10 timeout 1800 yes > /dev/null`. The workers run at low priority and stop by themselves after 30 minutes. Their PIDs are saved in `/var/lib/troubleshooting-lab/workers.pid`, and the fix stops only those PIDs.

## Customer ticket

> **From:** Jonas, support team lead. **Priority:** High
>
> "The server has become very slow. SSH takes forever to respond and the website is sluggish. Nothing was deployed today. Our customers are starting to complain."

## Symptoms

- Commands and logins feel slow.
- The load average is close to or above the number of CPU cores.
- All CPU cores are busy.

## Step-by-step diagnosis

**Step 1. How loaded is the machine?**

```bash
uptime
nproc
```

Example output:

```text
 10:31:02 up 1 day,  2:11,  1 user,  load average: 2.01, 1.20, 0.55
2
```

Load average 2.01 on 2 cores means the CPUs are fully busy. The three numbers are the last 1, 5 and 15 minutes. A rising 1-minute number means it just started.

**Step 2. Who is using the CPU?**

```bash
top
ps aux --sort=-%cpu | head -5
```

Example output from `top` (header and first rows):

```text
%Cpu(s):  0.0 us,  0.3 sy, 99.7 ni,  0.0 id,  0.0 wa
    PID USER      PR  NI    VIRT    RES  %CPU  %MEM  COMMAND
   2410 root      30  10    2816    896  99.7   0.0  yes
   2411 root      30  10    2816    896  99.3   0.0  yes
```

Notice `ni` (nice) instead of `us` in the CPU line: these processes run with a lowered priority (`NI` 10), so `top` counts their time under "nice".

**Step 3. Find out what the processes are and who started them.**

```bash
ps -eo pid,ppid,ni,etime,args --sort=-%cpu | head -6
```

Example output:

```text
  PID  PPID  NI     ELAPSED COMMAND
 2410  2409  10       00:42 yes
 2409  2188  10       00:42 timeout 1800 yes
```

The parent is `timeout 1800 yes`. The job is a leftover, it has an end time of 30 minutes, and it is not part of the website.

**Step 4. Look per process over time (optional).**

```bash
pidstat 1 3
htop
```

## Root cause

Runaway `yes` processes (one per core) were consuming all CPU time. They had low priority, so the server stayed alive but became sluggish.

## The fix

Manually, stop the parent and the child of the process you identified (check the PID first, do not guess):

```bash
sudo kill 2409 2410
# if they do not stop within a few seconds:
sudo kill -9 2409 2410
```

With `fix.sh`: it reads `workers.pid`, checks that each PID still looks like `timeout 1800 yes`, stops it and its child, removes the PID file and verifies that none are left. It never kills anything else.

## Verification

```bash
uptime
ps aux --sort=-%cpu | head -3
```

```text
[INFO] Stopping the recorded workers
[INFO] Stopped 2 recorded process(es).
[ OK ] No lab CPU workers are running
[PASS] Scenario 08-high-cpu is fixed. Everything is back to normal.
```

The load average takes a few minutes to fall, because it is an average over time.

## Suggested reply to the customer

Hi Jonas, I found the reason for the slowness. A few runaway background jobs were using all of the server's processor power, so everything else had to wait. They were not part of your website, so I stopped them, and the server is responding normally again. I will watch the load for the next hour and send you a note if I see anything unusual.

## Escalation notes

If a senior engineer had to take over, include:

- `uptime`, `nproc` and a screenshot or copy of `top` taken during the problem.
- The PID, parent PID, user, start time and full command of the process (`ps -eo pid,ppid,user,lstart,args`).
- Whether the process belongs to a known service or was started by hand, a cron job or a deployment.
- What you did, in order, and whether you killed anything (and with which signal).

## Key lessons

- Load average only means something when you compare it to the number of cores.
- Identify a process (what, who, since when) before you kill it. In production, ask first.
- Use `kill` (polite) before `kill -9` (forced), and always note what you stopped.

## Related commands to learn

`htop`, `pidstat`, `renice`, `pgrep`, `pkill`, `kill -l`, `nice`, `vmstat 1`.
