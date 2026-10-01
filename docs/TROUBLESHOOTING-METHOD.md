# Troubleshooting method

A support engineer is not paid to know every command. They are paid to find the cause calmly, fix it safely and explain it clearly. This lab uses the same six steps in every scenario.

## 1. Observe

Find out exactly what is wrong before you change anything.

- What does the customer see? What did they expect? Since when?
- Reproduce it yourself and copy the exact error message.
- Check what still works. "Ping by IP works, by name fails" is worth more than "the internet is broken".
- Do not change anything yet. Every change you make before you understand the problem makes it harder to understand.

## 2. Hypothesize

Turn the observations into a short list of possible causes, most likely first.

- Work from the bottom up: power and network, then name resolution, then firewall, then service, then application, then permissions.
- Think about what changed recently: updates, deployments, a colleague "tidying up".
- Use the error type as a clue:

| What you see | Likely meaning |
|--------------|----------------|
| Connection refused (instant) | Host reachable, nothing listens on that port |
| Connection timed out | Packets dropped: firewall or routing |
| Name or service not known | DNS or hosts file |
| 403 Forbidden | Permissions |
| 502 / 503 | A service behind the web server is down |
| No space left on device | Disk or inodes are full |
| Address already in use | Two programs want the same port |

## 3. Test

Prove or disprove one hypothesis at a time with a command that changes nothing (read-only).

- Prefer the simplest test: `ping`, `curl -v`, `systemctl status`, `ss -tulpn`, `df -h`, `ip route`.
- Make one change at a time. If you change three things and it works, you do not know which one fixed it.
- Test from the same place the customer is. `curl localhost` on the server cannot prove that the firewall is fine.
- Write down what you tried and what you saw. You will need it for the ticket.

## 4. Fix

Choose the smallest change that solves the root cause.

- Take a backup or note the original value first (`cp -a`, `stat`, `ip route`).
- Fix the cause, not just the symptom. Restarting a service that keeps stopping is not a fix.
- Never use `chmod 777`, `ufw disable` or `kill -9` as the first move.
- If the change is risky or you are not sure, stop and escalate.

## 5. Verify

Check that the problem is really gone, in the way the customer experiences it.

- Repeat the exact test that failed in step 1.
- Check that you did not break anything else (other sites, other users, other ports).
- Check that the fix survives a restart where it matters (`systemctl enable`, saved configuration).

## 6. Document

Write the ticket while the facts are fresh. Use [TICKET-TEMPLATE.md](TICKET-TEMPLATE.md).

- Summary and impact in plain language.
- What you found and the root cause.
- What you changed, with the exact commands.
- A reply the customer can understand without technical knowledge.
- Escalation notes: what a senior engineer needs to continue without asking you ten questions.

## Habits of a good support engineer

- Stay calm and polite, especially when the ticket is marked urgent.
- Say what you know, what you do not know and what you will do next.
- Admit mistakes early, fix them and write them down.
- Do not guess in production. Ask, or escalate with good notes.
