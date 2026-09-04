---
name: validate
description: Pre-PR readiness check for the clean-room process. Scans the branch's changed code for provenance GAPS — unfenced regions, HUMAN-AUTHORED sections needing a DDR decision, DDR references that don't resolve, (regulated) AI-DRAFTED/FLAGGED blocks with no cited Sources, open FLAGGED fences, malformed fences — and walks the developer through fixing each, so the PR passes the server gate the FIRST time. A section the developer says needs no DDR is recorded as `DDR: none`, so re-running never asks about it again. Run it after `tag` and before opening a PR. Authoring aid — the server-side gate is still the independent auditor; never fabricates a DDR rationale or a citation.
---

# validate — make the branch pass the gate before you open the PR

## When to run
After you've written/edited code (and run `tag` to label human regions), before opening the PR. It finds
everything the server gate would reject and fixes it interactively, so you don't discover the gaps as a red
check after pushing.

## What it does NOT do
It does not fabricate anything. A DDR's rationale is the developer's own words; a `Sources:` citation is a
real approved source you consulted. `validate` gathers those from you (or the sources MCP) — it never
invents them. It is an authoring aid; the gate remains the independent check.

## Procedure
1. **Scan.** Run the read-only scanner and read its findings (one per line: `KIND<TAB>location<TAB>detail`):
   - `bash .claude/skills/validate/scripts/validate_scan.sh` — changed files vs `origin/main` (the default)
   - `… <path>` for one file/dir, or `… --all` for the whole working tree.
   If it prints nothing, the branch is clean — say so and stop.

2. **Remediate each finding, by KIND.** Confirm every action with the developer; apply directly once they
   answer (no separate approval step). A section already resolved (`DDR: none`, `BOILERPLATE`, or a DDR ref
   that resolves) is never reported, so you only touch real gaps.

   - **UNTAGGED** — the file has unfenced code. Hand off to the **`tag`** skill on that file, then re-scan.
   - **DDR-NEEDED** — a `HUMAN-AUTHORED` fence with `DDR: TBD`/no ref. Offer three clear choices:
       • **Record a new decision** → the developer gives the rationale + options in their own words; write
         `docs/ddr/DDR-<id>.md` (mint a random id), set `DDR: DDR-<id>` in the fence, and **sign it**
         (`bash .claude/throughmark/bin/sign_ddr.sh docs/ddr/DDR-<id>.md`).
       • **No DDR needed** → set the fence's field to `DDR: none` (this is the "don't ask again" marker).
       • **Not really human-conceived / standard** → downgrade the fence tag to `BOILERPLATE` (drop `DDR:`).
     Never invent a rationale; if the developer won't give one and it isn't standard, leave it and move on.
   - **DDR-MISSING-FILE** — the fence cites `DDR: DDR-<id>` but no `docs/ddr/DDR-<id>.md` exists. Either fix
     the fence to the correct existing id, or create that record (as in DDR-NEEDED) and sign it.
   - **SOURCE-NEEDED** (regulated) — an `AI-DRAFTED`/`FLAGGED` block with no `Sources:`. Use the
     **throughmark-sources** MCP (`search_approved_sources`, pass the block's Trace) to find an approved
     source, then add the `Sources:` line to the fence header. If there is genuinely no source, reconsider
     the tag (is it really boilerplate?) or mark it for reviewer attention — don't invent a citation.
   - **FLAGGED-OPEN** — code the guardrail flagged as resembling a known source. Do NOT silence it: help the
     developer either rewrite it from first principles (then re-tag) or escalate it for similarity
     screening / Compliance review. A FLAGGED fence should not reach a PR unresolved.
   - **MALFORMED-FENCE / BAD-TAG** — fix the structure: every `PROVENANCE-BEGIN` has a matching `-END`, and
     the tag is one of BOILERPLATE / AI-DRAFTED / FLAGGED / HUMAN-AUTHORED (vendor/baseline tags as issued).

3. **Re-scan until clean**, then report: how many gaps were resolved and that the branch should now pass
   `throughmark-provenance` / `throughmark-audit` (and `throughmark-sources` in regulated mode).

## Editing a fence field
Change only the header comment of the exact fence at the reported line — e.g. `DDR: TBD` → `DDR: none`, or
add `  Sources: <approved source>` on the comment line just below the `PROVENANCE-BEGIN`. Never alter the
code inside the fence, and never touch a fence the scan didn't flag.

## Do NOT
- Fabricate, paraphrase, or "improve" a DDR rationale, or invent a `Sources:` citation.
- Mark `DDR: none` on the developer's behalf — it's their explicit decision that the section embodies no
  recorded design choice.
- Silence a `FLAGGED` fence to make the scan pass — resolve it.
- Edit code logic, or any fence the scanner did not report.

*Authoring aid for the clean-room process. Not legal advice. The server-side gate (throughmark-provenance /
audit / sources) and the independent similarity screen remain the authoritative checks.*
