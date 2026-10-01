# Scenario 05: Disk full

**Difficulty:** Beginner
**Estimated time:** 20 minutes

The break creates one hidden file `/var/tmp/.lab-bigfile`. Its size is the smaller of `LAB_DISK_MB` (default 5120) and the free space minus 1 GB, so at least 1 GB always stays free. If the result would be under 100 MB, the break stops. To fill almost the whole disk, set a very large value: `LAB_DISK_MB=1000000 sudo ./lab.sh break 5`.

## Customer ticket

> **From:** Alex, IT administrator. **Priority:** Medium
>
> "Our server is almost out of disk space and the monitoring alert keeps firing. Nobody on the team knows what is using it. Please find it before the nightly backup fails."

## Symptoms

- `df -h` shows the disk much fuller than before.
- With a very large `LAB_DISK_MB`, programs start to fail with "No space left on device".

## Step-by-step diagnosis

**Step 1. Which filesystem is full?**

```bash
df -h
```

Example output:

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        30G   21G  8.0G  73% /
tmpfs           961M     0  961M   0% /dev/shm
```

**Step 2. Which folders use the space?** `-x` stays on one filesystem, `sort -h` sorts by human sizes.

```bash
sudo du -xh / --max-depth=2 2>/dev/null | sort -h | tail -6
```

Example output:

```text
1.2G	/usr/lib
1.8G	/usr
5.1G	/var/tmp
5.3G	/var
21G	/
```

**Step 3. Find the large files.**

```bash
sudo find / -xdev -size +500M 2>/dev/null
ls -lah /var/tmp
```

Example output:

```text
/var/tmp/.lab-bigfile
-rw------- 1 root root 5.0G Oct  1 10:30 .lab-bigfile
```

The name starts with a dot, so a plain `ls` hides it. Use `ls -a`.

**Step 4. Rule out "deleted but still open" files.** If you delete a big file and the space does not come back, a process may still hold it open.

```bash
sudo lsof +L1
```

In this scenario there is no output, which means no deleted file is still held open.

## Root cause

One 5 GB hidden file in `/var/tmp` used up the free space. Nothing was broken in the system itself.

## The fix

Manually (after you have checked that the file is not needed):

```bash
sudo rm /var/tmp/.lab-bigfile
```

With `fix.sh`: it removes only `/var/tmp/.lab-bigfile`, checks that it is gone and prints the free space before and after.

## Verification

```bash
df -h /
```

```text
[INFO] Removing /var/tmp/.lab-bigfile
[ OK ] /var/tmp/.lab-bigfile is gone
[INFO] Free space on /var/tmp is now 13312 MB (before the lab: 13312 MB)
[PASS] Scenario 05-disk-full is fixed. Everything is back to normal.
```

## Suggested reply to the customer

Hi Alex, I found what was filling the disk: one very large hidden file in the temporary folder. It was not part of the system or the website, so I removed it and the free space is back to normal. The backup will have room tonight. To avoid a repeat, I suggest a disk alert at 80 percent and a weekly clean-up of the temporary folder.

## Escalation notes

If a senior engineer had to take over, include:

- `df -h` and `df -i` output (inodes can also run out).
- The biggest folders (`du -xh / --max-depth=2 | sort -h | tail`) and the biggest files.
- What the large file is, who owns it and when it was created (`ls -la`, `stat`).
- Whether deleted files are still held open (`lsof +L1`) and whether logs are being rotated.

## Key lessons

- `df` tells you which disk is full. `du` tells you what fills it.
- Never delete a big file before you know what it is.
- If space does not come back after a delete, check `lsof +L1` for files that are deleted but still open.

## Related commands to learn

`df -i`, `ncdu`, `find -size`, `stat`, `logrotate`, `journalctl --vacuum-size=200M`.
