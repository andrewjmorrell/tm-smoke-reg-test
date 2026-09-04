---
name: review-assist
description: Prepare a clean-room PR for a qualified reviewer — assemble the diff, each AI-DRAFTED/FLAGGED block next to its cited source and each HUMAN-AUTHORED block next to its DDR, list what still needs checking, and enforce that the reviewer is NOT the author — then hand off to validity-signoff (or the GitHub web Approve). Use when you're helping someone review a PR. Organizes evidence for the human's judgment; never decides validity itself.
---

# review-assist — organize a PR for a qualified reviewer

## When
Someone is about to review a clean-room PR and wants the provenance evidence laid out so they can judge it
efficiently. This PREPARES the review; the sign-off itself is `validity-signoff` (or web Approve).

## The rule that cannot bend
The **reviewer is a human, and must not be the PR author** (separation of duties). This skill does not
judge validity — it organizes evidence so the human can. If the current user IS the author, say so and
stop: someone else must review.

## Procedure
1. Pull the PR diff and, for each changed block, pair it with its provenance:
   - `AI-DRAFTED` / `FLAGGED` → show the `Sources:` it cites (regulated) so the reviewer can check the code
     against the actual source; flag any that cite nothing.
   - `HUMAN-AUTHORED` → show the referenced `DDR-<id>` and its rationale.
   - `BOILERPLATE` → note it's standard, lower-scrutiny.
2. Run `validate` / read `gh pr checks` and list what's unresolved (open flags, missing sources/DDRs).
3. Give the reviewer a checklist: does each AI block match its cited source? Is each human decision real and
   recorded? Any resemblance to screen? 
4. Hand off: web **Approve** on the PR records the sign-off automatically, or run `validity-signoff` from
   the terminal.

## Rules
- Never mark anything valid or post `throughmark-validity` from here — that's the reviewer's act via
  `validity-signoff` / web Approve.
- Never present the author as an eligible reviewer.

*Authoring aid. The qualified human reviewer's judgment is authoritative.*
