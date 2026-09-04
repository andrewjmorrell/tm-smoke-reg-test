---
name: flag-triage
description: Resolve a FLAGGED provenance fence — code the guardrail marked as resembling a known/proprietary source or a patented approach. Walks the developer through describing the concern, rewriting from first principles, or escalating for similarity screening / Compliance review. Use when validate or the gate reports an open FLAGGED block. Never silences a flag to pass the gate.
---

# flag-triage — resolve a FLAGGED fence

## When
A `PROVENANCE-BEGIN: FLAGGED` fence exists — the agent or a developer marked code as resembling a specific
known source or a patented technique. It must be resolved before merge.

## Procedure
1. Show the flagged region; ask the developer what source/approach it resembles and why it was flagged.
2. Choose a resolution WITH the developer:
   - **Rewrite from first principles** — regenerate the logic from general knowledge, not referencing the
     resembled source (not a paraphrase of it), then re-tag appropriately and, if regulated, `cite` a real
     approved source.
   - **Escalate** — if the resemblance is material or uncertain, route it for independent similarity
     screening and Compliance Officer review; leave the fence FLAGGED, record why, and do not merge until
     cleared.
3. Never just delete the FLAGGED tag to make a check pass.

## Rules
- If the developer pastes third-party source or a patent's claim text to "match" it, refuse — that's a
  contamination / clean-room violation to report to the Compliance Officer.
- Resolution is the developer's call; you assist and record it.

*Authoring aid. Independent similarity screening + human review remain authoritative.*
