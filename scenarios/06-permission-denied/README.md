# Scenario 06: Permission denied (HTTP 403)

**Difficulty:** Beginner
**Estimated time:** 15 minutes

## Customer ticket

> **From:** Sofia, office manager. **Priority:** Medium
>
> "Good morning, our website now shows '403 Forbidden' instead of the home page. Yesterday a colleague was tidying up the server files. It worked fine before that. Please help soon."

## Symptoms

- The browser shows "403 Forbidden" with an nginx page.
- nginx is running and answers quickly. This is not an outage, it is a refusal.

## Step-by-step diagnosis

**Step 1. Look at the HTTP status code.**

```bash
curl -I http://localhost
```

Example output:

```text
HTTP/1.1 403 Forbidden
Server: nginx/1.24.0 (Ubuntu)
Date: Thu, 01 Oct 2026 18:43:16 GMT
Content-Type: text/html
```

403 means "I understood you, but you are not allowed". The server is up. It is a permission problem, not a network problem.

**Step 2. Ask nginx why.**

```bash
sudo tail -n 3 /var/log/nginx/error.log
```

Example output:

```text
2026/10/01 18:43:16 [error] 2756#2756: *4 "/var/www/html/index.html" is forbidden (13: Permission denied), client: 127.0.0.1, server: _, request: "HEAD / HTTP/1.1", host: "localhost"
```

`13: Permission denied` is the operating system saying no to the nginx worker.

**Step 3. Find out who nginx runs as.**

```bash
ps aux | grep '[n]ginx'
```

Example output:

```text
root      2755  0.0  0.0  11168  1868 ?   Ss   18:41   0:00 nginx: master process nginx
www-data  2756  0.0  0.0  11540  3516 ?   S    18:41   0:00 nginx: worker process
```

The master runs as root, but the worker that reads files runs as `www-data`.

**Step 4. Check every folder on the path, from `/` down to the file.**

```bash
namei -l /var/www/html/index.html
```

Example output:

```text
f: /var/www/html/index.html
drwxr-xr-x root root /
drwxr-xr-x root root var
drwxr-xr-x root root www
drwx------ root root html
-rw-r--r-- root root index.html
```

The file is readable, but the folder `html` is `drwx------`: only root may enter it. `www-data` cannot even reach the file.

## Root cause

The web root `/var/www/html` had mode `700` and owner `root:root`. The nginx worker (`www-data`) was not allowed to enter the folder, so every request got 403.

## The fix

Manually (the normal values are owner `root:root`, mode `755`):

```bash
sudo chmod 755 /var/www/html
sudo chown root:root /var/www/html
```

Do not "fix" this with `chmod 777`. It opens the folder to everyone.

With `fix.sh`: it restores the exact owner, group and mode that were recorded with `stat` before the break, then checks them and requests the page.

## Verification

```bash
ls -ld /var/www/html
curl -I http://localhost
```

```text
[INFO] Restoring /var/www/html: owner root:root, mode 755
[ OK ] /var/www/html has owner root:root and mode 755 again
[ OK ] The site answers HTTP 200 again
[PASS] Scenario 06-permission-denied is fixed. Everything is back to normal.
```

## Suggested reply to the customer

Hi Sofia, your website is working again. While tidying up, the permissions of the website folder were changed, so the web server was no longer allowed to read the pages and showed "Forbidden". I put the permissions back to their normal setting, and the home page loads correctly. Please let your colleague know that the website folder should not be changed without asking, and I am happy to help with any clean-up.

## Escalation notes

If a senior engineer had to take over, include:

- The HTTP status code, the matching line from `/var/log/nginx/error.log` and the time.
- The output of `namei -l` for the requested file and `ps aux | grep nginx` (which user nginx runs as).
- What the permissions should be, and how you know (another server, the package default).
- Whether SELinux or AppArmor could be involved (not on a default Ubuntu nginx, but worth stating).

## Key lessons

- A 403 means the server is alive and refusing. Read the error log for the reason.
- `namei -l` shows the permissions of every folder on the path. One closed folder is enough to block a file.
- Restore permissions to the original values. Never use `777` as a shortcut.

## Related commands to learn

`stat`, `chmod`, `chown`, `id www-data`, `sudo -u www-data cat /var/www/html/index.html`, `getfacl`.
