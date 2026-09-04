---
name: status
description: Show the clean-room compliance status of the current branch before a PR — which ThroughMark checks will likely pass or fail, which sections still need a DDR or a source, whether a validity sign-off is pending, and the single next action. A read-only "where am I?" summary. Use to see if the branch is PR-ready.
---

# status — compliance readiness of the current branch

## When
Any time you want a quick read on whether the branch will pass the gate, without pushing.

## Procedure (READ-ONLY — report, change nothing)
1. Run `bash .claude/skills/validate/scripts/validate_scan.sh` and summarize gaps by kind (untagged,
   DDR-needed, missing-DDR, source-needed, flagged, malformed).
2. Note the branch and its base; if `gh` is available and a PR exists, read `gh pr checks`.
3. Give a short readiness report:
   - **Provenance / audit** — passes iff no untagged/malformed/DDR findings.
   - **Sources** (regulated) — passes iff no `SOURCE-NEEDED` gaps.
   - **Validity** (regulated) — needs a qualified reviewer's Approve after the PR is green; flag if pending.
4. End with the single next action (e.g. "run `/validate` to clear 3 DDR gaps, then open the PR").

## Rules
- Read-only. Do not edit fences, DDRs, or code — that's `validate`'s job.

*Authoring aid. The server gate is the authoritative status.*
