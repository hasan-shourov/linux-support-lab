# Support ticket template

Copy this template for each scenario. Write short, factual sentences. Someone who was not there should be able to understand the ticket without asking you anything.

```markdown
# Ticket: <short title>

**Reported by:** <name, team>
**Priority:** <Low | Medium | High | Urgent>
**Date and time reported:** <YYYY-MM-DD HH:MM>
**Handled by:** <your name>

## Summary
One or two sentences. What is the problem, in the customer's words?

## Impact
Who or what is affected? Is anything blocked? How urgent is it, and why?

## Steps to reproduce
1. <what you did>
2. <what you saw>

## Findings
What you checked, in order, and what each check showed. Include the exact commands and the important lines of output.

- `command` showed <result>
- `command` showed <result>

## Root cause
The one thing that was actually wrong. Separate the cause from the symptom.

## Resolution
What you changed to fix it, with the exact commands. Mention what you tested afterwards.

## Customer reply
3 to 5 plain-English sentences. No jargon. What was wrong, what you did, what the customer should expect now.

## Escalation notes
What a senior engineer would need if this came back or had to be handed over:
- Hostname, OS version, time of the problem
- Exact error messages and relevant log lines
- Output of the key diagnostic commands
- What you already tried and what you changed
- Open questions and risks
```

## A filled example (scenario 03)

```markdown
# Ticket: Company website is down

**Reported by:** Maria, shop owner
**Priority:** Urgent
**Date and time reported:** 2026-10-01 10:18
**Handled by:** Mehedi

## Summary
The company website does not load. Visitors see an error page.

## Impact
All visitors are affected and the shop is losing orders. No workaround.

## Steps to reproduce
1. Opened the site in a browser: "unable to connect".
2. Ran `curl -I http://localhost` on the server: "Connection refused" immediately.

## Findings
- `systemctl status nginx` showed "inactive (dead)" since 10:14.
- `journalctl -u nginx -n 10` showed a clean stop ("Deactivated successfully"), no crash.
- `ss -tulpn | grep :80` showed nothing listening on port 80.

## Root cause
The nginx service had been stopped, so nothing was listening on port 80.

## Resolution
Ran `sudo systemctl start nginx` and `sudo systemctl enable nginx`. `curl -I http://localhost` returned 200 OK.

## Customer reply
Hi Maria, your website is back online. The program that serves the site had been switched off on the server. I started it again and tested the site. I am now checking who or what stopped it, and I will tell you if I find a reason.

## Escalation notes
- Server web01, Ubuntu 24.04, stopped at 10:14 (clean stop, not a crash).
- Need to find out who or what stopped it: check shell history, deployment jobs and cron around 10:14.
- Service is enabled for boot.
```
