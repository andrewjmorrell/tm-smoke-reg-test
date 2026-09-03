---
name: baseline-tag
description: Onboard an existing, untagged repository into the clean-room process by adding a neutral BASELINE provenance header to every pre-existing source file. BASELINE means "provenance not established" — NOT a claim of human or AI authorship. Idempotent (never re-tags already-tagged files); run once at integration, then commit as a single baseline commit that becomes the cut-line. Baseline code is exempt from DDRs and the provenance gate; tracking applies to code created after the cut-line.
---

# baseline-tag — onboard an existing repo

## When to run
Once, when a client adds the clean-room tool to a **codebase that already exists** and has no provenance
tags. It marks everything present at integration as `BASELINE` so the gate has a clean starting line;
from the next commit onward, new AI/human work is fenced and tagged normally.

## The one rule that matters
`BASELINE` is **neutral** — it records that the provenance of pre-existing code is **not established**.
Do **not** tag pre-existing code `HUMAN-AUTHORED` (or any AI tag): you don't actually know who/what wrote
it, and a false authorship claim would poison the audit trail. BASELINE is exempt from DDRs and the gate.

## Procedure
1. **Dry run** to see scope:
   `bash .claude/skills/baseline-tag/scripts/baseline_tag.sh . `
   Review the `WOULD-TAG` list — confirm it's source code, not vendored/generated/build output (those
   are auto-excluded, but sanity-check).
2. **Apply**:
   `bash .claude/skills/baseline-tag/scripts/baseline_tag.sh . --apply`
   Each source file gets a top-of-file header, e.g. `// PROVENANCE: BASELINE  ...  Cut-line: <sha>`.
3. **Verify the build still passes** (headers are comments, but check).
4. **Commit as ONE commit** titled e.g. `chore: baseline provenance tagging (clean-room cut-line)`.
   That commit is the **cut-line**; `.claude/throughmark/baseline` records it. Everything after is tracked.

## What it does / doesn't touch
- **Tags:** known source languages only (`.kt .java .py .js/.ts .go .c/.cpp .cs .rs .rb .sh .sql`, …),
  with the file's native comment syntax; shebang stays on line 1.
- **Skips:** files already containing any `PROVENANCE` tag (idempotent), and vendored/generated/build
  dirs (`node_modules`, `vendor`, `build`, `dist`, `target`, `.git`, `reference-corpus`, …), and
  non-code/data files (no comment syntax → not tagged).
- **Never** overwrites existing tags/fences or changes code logic.

## What the top-of-file header means (and what happens when a baseline file is later edited)
The header is a **whole-file** marker with **no closing fence** on purpose: the "end" of baseline is
defined in **time** — the cut-line commit recorded in `.claude/throughmark/baseline` — not by a marker lower in
the file. Everything present at the cut-line is baseline; anything added afterward is net-new work.

So the header does **not** license new code to hide under it. **The moment anyone edits a BASELINE
file, convert it:** fence the pre-existing code as `PROVENANCE-BEGIN/END: BASELINE` and give the new
code its own fence (or leave human additions unfenced). The gate enforces this — a whole-file BASELINE
file that has changed since the cut-line but still lacks any `PROVENANCE-BEGIN` fence fails with
`BASELINE-EDITED` until it is converted. (The clean-room guardrail instructs the AI to do this
conversion automatically on first edit.)

## Notes
- One-time and large: the baseline commit will touch many files — that's expected; keep it as its own
  commit so the boundary is clean and reviewable.
- Edge case: a language with a strict line-1 requirement (e.g. a Python encoding cookie) may need the
  header moved to line 2 — verify such files after applying.
- After baselining, the `tag` skill and the gate operate only on code added past the cut-line.
