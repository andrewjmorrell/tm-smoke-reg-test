---
name: cite
description: Find and cite an approved source for AI-assisted code in a regulated clean-room repo. Runs the throughmark-sources MCP to search the client's approved sources for what you're implementing, logs the consultation to the audit sink, and inserts the correct `Sources:` line into the provenance fence — so citing is one step. Use while writing AI-DRAFTED code that needs a source, or when validate reports SOURCE-NEEDED. Never invents a citation.
---

# cite — consult an approved source and record it in the fence

## When
Regulated mode: an `AI-DRAFTED`/`FLAGGED` block must cite a checkable source it was consulted against. Use
while writing such code, or when `validate` / the gate reports `SOURCE-NEEDED`.

## Procedure
1. Identify the block's trace id (its fence `Trace:` or the work item).
2. Search approved sources: call the **throughmark-sources** MCP `search_approved_sources(query, trace)`
   with a query describing what the block does. This logs a consultation to the sink under that trace.
3. Show the developer the code matches + approved references returned; let them pick the one they actually
   drew from (or confirm none applies).
4. Add a `Sources:` line to the fence header — on the comment line just below `PROVENANCE-BEGIN` — citing the
   chosen source (URL / `org/repo@ref#path` / internal doc id), with `Retrieved: <ISO>` for web sources, in
   the file's comment syntax.

## Rules
- Cite only a source the developer actually consulted/drew from — never attach a plausible URL to satisfy
  the check. If nothing applies, the code may be `BOILERPLATE` (no source) or needs rethinking; don't fabricate.
- If the sources MCP isn't configured (clean-room repo, or no `TM_SINK_BUCKET`/`TM_SOURCES_URI`), say so —
  citing is a regulated-mode step.
- Never edit code inside the fence; only add the `Sources:` header line.

*Authoring aid. The throughmark-sources gate independently cross-checks cited sources against the consultation log.*
