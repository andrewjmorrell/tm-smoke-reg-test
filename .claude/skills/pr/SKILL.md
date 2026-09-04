---
name: pr
description: Open a pull request for clean-room work with a provenance-aware description — what was generated (by tag), which decisions were deferred to the human and their DDRs, sources cited (regulated), and any flags — after running validate so the PR doesn't open with known gaps. Use to open the PR that goes to the gate and a qualified reviewer. Runs the checks first; never hides an open flag from the reviewer.
---

# pr — open a PR the gate and reviewer can trust

## When
Branch is committed and you want to open the pull request that hits the ThroughMark gate and a reviewer.

## Procedure
1. Run `bash .claude/skills/validate/scripts/validate_scan.sh`. If gaps remain (untagged, DDR-needed,
   SOURCE-NEEDED, open FLAGGED, malformed), surface them and offer to resolve first — a PR should not open
   with known provenance gaps.
2. Push the branch. Build the PR body as a provenance summary (reuse `session-summary` if handy):
   - **Generated** — by tag (BOILERPLATE / AI-DRAFTED / HUMAN-AUTHORED / FLAGGED), with files.
   - **Human-conceived** — decisions deferred to the developer and their `DDR-<id>`s.
   - **Sources** (regulated) — approved sources cited and the blocks that cite them.
   - **Flags** — any FLAGGED items and triage state.
3. End the PR description with the audit trailer:
   ```
   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   ```
4. Open with `gh pr create`. Report the URL and the next action (the gate runs; a qualified reviewer — not
   the author — must approve to post `throughmark-validity`).

## Rules
- Never open a PR that hides an open FLAGGED block or untagged code from the reviewer — call it out in the
  body.
- The author cannot sign off their own validity (separation of duties) — say who needs to review.

*Authoring aid. The gate's checks and the reviewer's sign-off are authoritative.*
