# Scenario 07: SSH failure

**Difficulty:** Intermediate
**Estimated time:** 30 minutes

This is a safe simulation: it makes the `~/.ssh` folder of the user who ran `sudo` writable by everyone (`chmod 777`), so `sshd` refuses key login because of `StrictModes`. With the optional flag `--with-password-disable` it also writes `/etc/ssh/sshd_config.d/00-lab.conf` with `PasswordAuthentication no` (the name starts with `00` because sshd uses the first value it finds). The configuration is validated with `sshd -t` before it is reloaded.

**Keep a second SSH session open while you work.** Existing sessions are not closed by this scenario, and everything is reverted automatically after `LAB_REVERT_SECONDS` (default 600 seconds, 10 minutes).

## Customer ticket

> **From:** Lena, developer. **Priority:** High
>
> "Hi team, I cannot log in to the server over SSH with my key since this morning. It worked yesterday and I did not change my keys. I need to deploy today, so this is quite urgent."

## Symptoms

- Login with the SSH key no longer works. With password login still enabled, the client asks for a password instead. With `--with-password-disable`, the login ends with `Permission denied (publickey)`.
- The server answers and the SSH service is running.

## Step-by-step diagnosis

**Step 1. Watch the login attempt in detail (from another machine).**

```bash
ssh -vvv lena@SERVER-IP
```

Example output (shortened):

```text
debug1: Offering public key: /home/lena/.ssh/id_ed25519 ED25519 SHA256:Zk3...
debug1: Authentications that can continue: publickey,password
debug1: Next authentication method: password
lena@SERVER-IP: Permission denied (publickey).
```

The key was offered and not accepted. The client cannot say why. Only the server knows.

**Step 2. Read the server log (use your second session).**

```bash
sudo journalctl -u ssh -n 20 --no-pager
sudo tail -n 20 /var/log/auth.log
```

Example output:

```text
sshd[2210]: Authentication refused: bad ownership or modes for directory /home/lena/.ssh
```

**Step 3. Check the folder it names.**

```bash
ls -ld ~/.ssh
```

Example output:

```text
drwxrwxrwx 2 lena lena 4096 Oct  1 09:15 /home/lena/.ssh
```

**Step 4. Look at the active SSH settings.**

```bash
sudo sshd -T | grep -Ei 'strictmodes|passwordauthentication|pubkeyauthentication'
```

Example output (with `--with-password-disable`):

```text
pubkeyauthentication yes
passwordauthentication no
strictmodes yes
```

If `passwordauthentication no` appears and you did not set it, look in `/etc/ssh/sshd_config.d/` for a file that does.

## Root cause

The `.ssh` folder was writable by everyone. With `StrictModes yes` (the default), sshd refuses keys from a folder that other users could change, because someone could replace the authorized keys. Optionally, password login had also been turned off, which removed the fallback.

## The fix

Manually:

```bash
chmod 700 ~/.ssh
# Only if you used --with-password-disable:
sudo rm /etc/ssh/sshd_config.d/00-lab.conf
sudo sshd -t
sudo systemctl reload ssh
```

Never turn `StrictModes` off to make this go away.

With `fix.sh`: it cancels the pending auto-revert, restores the owner and mode recorded before the break (and removes `.ssh` if the lab had to create it), removes the lab drop-in if present, validates with `sshd -t` and reloads the service.

## Verification

```bash
ls -ld ~/.ssh
ssh lena@SERVER-IP
```

```text
[INFO] Restoring /home/lena/.ssh: owner lena:lena, mode 700
[ OK ] /home/lena/.ssh permissions are back to normal
[ OK ] The lab SSH drop-in is removed
[ OK ] sshd accepts its configuration
[PASS] Scenario 07-ssh-failure is fixed. Everything is back to normal.
```

## Suggested reply to the customer

Hi Lena, I found the problem. The folder on the server that holds your SSH key list had permissions that were too open, and the server refuses to trust keys from a folder that others could change. I set the permissions back to the safe setting and your key works again. Please do not loosen permissions on that folder in the future, and let me know if the login still gives you trouble.

## Escalation notes

If a senior engineer had to take over, include:

- The client side output of `ssh -vvv` and the matching server log lines with the time.
- `ls -ld` of the home folder, `~/.ssh` and `authorized_keys`, and the output of `sshd -T`.
- Whether anything under `/etc/ssh/sshd_config.d/` changed recently.
- Which users are affected, and whether any working session is still open (do not close it).

## Key lessons

- The client shows that a login failed. The server log shows why. Always read both sides.
- SSH is strict about permissions on purpose. Fix the permissions, never the safety check.
- Before reloading `sshd`, run `sshd -t`, and keep a second session open.

## Related commands to learn

`ssh-copy-id`, `ssh-keygen`, `sshd -t`, `sshd -T`, `chmod 700 ~/.ssh`, `chmod 600 ~/.ssh/authorized_keys`, `last`.
