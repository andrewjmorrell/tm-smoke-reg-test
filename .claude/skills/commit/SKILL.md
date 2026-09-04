---
name: commit
description: Stage and commit the current work as a clean, auditable commit — Conventional Commit subject, a Trace/work-item reference, and the Co-Authored-By: Claude trailer that the audit trail expects — after first running validate so provenance gaps are caught before they land. Use to commit clean-room work. Refuses to bury unresolved FLAGGED/untagged findings; surfaces them first.
---

# commit — an auditable clean-room commit

## When
You're ready to commit staged or unstaged clean-room changes.

## Procedure
1. Run `bash .claude/skills/validate/scripts/validate_scan.sh` first. If it reports untagged code, open
   FLAGGED fences, missing DDRs, or (regulated) missing Sources, surface them and offer to fix via
   `validate` / `tag` / `flag-triage` / `cite` BEFORE committing — don't commit over them silently.
2. Show the developer what will be staged; confirm scope (never commit secrets, keys, `.pem`, or the
   client env files).
3. Write a **Conventional Commit**: `type(scope): subject`, a body if useful, and reference the
   work-item/`Trace:` id. Keep the trailer the guardrail requires:
   ```
   Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
   ```
4. Commit. Report the SHA and the one next action (push / open PR via `pr`).

## Rules
- Never commit if validate shows an unresolved FLAGGED block or untagged code without telling the
  developer and getting an explicit go-ahead.
- Never stage secrets or customer data.

*Authoring aid. The developer approves the commit; branch protection still requires a non-author reviewer.*
