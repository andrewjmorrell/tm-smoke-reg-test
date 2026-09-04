---
name: refactor-safe
description: Refactor existing code — rename, extract, deduplicate, restructure — while preserving every provenance fence, tag, DDR reference, and Sources/Trace header exactly, so a cleanup never quietly relabels human-conceived code as AI boilerplate or drops an audit trail. Use for structural changes to fenced code. Behavior-preserving; never changes what a novel block does or who it's attributed to.
---

# refactor-safe — restructure without breaking provenance

## When
Renaming, extracting functions/modules, deduplicating, or reorganizing code that already carries
provenance fences.

## Procedure
1. Before editing, note each fenced region's tag, `Agent`/`Developer`, `Trace`, `DDR`, and `Sources`.
2. Refactor for structure only — behavior-preserving. When code moves, its fence moves WITH it verbatim:
   a HUMAN-AUTHORED block stays HUMAN-AUTHORED with the same `DDR:` and `Trace:`; an AI-DRAFTED block keeps
   its `Sources:`. Never merge a human region and a boilerplate region under one tag.
3. If a refactor would split a fenced block across new files, reproduce the correct fence in each part. If
   it would genuinely change behavior of a novel block, STOP — that is new conception, route to the
   developer / `ddr-draft`, not a refactor.
4. Run tests (or `write-tests`) to confirm behavior is unchanged; run `validate` to confirm no fence was
   dropped or malformed.

## Rules
- Never change a tag, `DDR:`, `Sources:`, or attribution to make the diff simpler.
- Behavior-preserving only. New behavior or a new novel decision is out of scope for this skill.

*Authoring aid. `validate` and the gate confirm fences survived the refactor.*
