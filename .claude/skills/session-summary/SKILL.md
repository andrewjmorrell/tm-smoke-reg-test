---
name: session-summary
description: Produce the end-of-session clean-room summary the interaction protocol calls for — items generated (with provenance tags), decisions deferred to the human, DDRs recorded, concerns flagged, and items to send for similarity screening. Use at the end of a coding session or before a PR to create the audit-friendly wrap-up. Summarizes what happened; never fabricates.
---

# session-summary — end-of-session provenance wrap-up

## When
At the end of a working session, or before opening a PR.

## Procedure
1. From the session's changes (and `bash .claude/skills/validate/scripts/validate_scan.sh`), assemble:
   - **Generated** — code produced this session, grouped by tag (BOILERPLATE / AI-DRAFTED / HUMAN-AUTHORED
     / FLAGGED), with file references.
   - **Deferred to the human** — novel/domain decisions handed to the developer, and DDRs recorded (ids).
   - **Sources** (regulated) — approved sources consulted (via `cite` / the MCP) and which blocks cite them.
   - **Flagged** — any FLAGGED items and their triage state.
   - **To screen** — anything to send for similarity screening / review.
2. Present it concisely (a few lines per section). Offer to drop it into the PR description.

## Rules
- Report only what actually happened this session — never invent decisions, sources, or rationale.

*Authoring aid for the audit trail. Not the auditor.*
