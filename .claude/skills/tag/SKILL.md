---
name: tag
description: Tag human-written code that has no provenance fence. Identifies human code by the ABSENCE of an AI fence (not by git history), wraps each unfenced region as HUMAN-AUTHORED (or BOILERPLATE for standard constructs), merges adjacent same-tag fences, and never touches existing fences. Operates silently, with ONE exception: when it applies a HUMAN-AUTHORED tag it prompts once for a DDR reference and lets you enter an id or skip (recording DDR: none). The provenance-tag-checker audits later.
---

# tag — provenance tagging for human-written code

## Core model (read first)
AI-generated code is **fenced at generation time** by the coding agent
(`// PROVENANCE-BEGIN/END: BOILERPLATE|AI-DRAFTED|FLAGGED`). Therefore **any code NOT inside a fence
is human-authored by definition.** This skill's job is to tag those unfenced human regions. Do **not**
use `git diff` to guess who wrote what — git shows *what* changed, not *who* authored it (that was the
old, broken approach). Authorship comes only from the presence/absence of fences.

## When to run
After a human has written or edited code, before opening a PR — to give the human's unfenced regions
explicit HUMAN-AUTHORED / BOILERPLATE tags for the audit trail.

## Scope / targets — what to tag
The developer picks the scope; pass it to the scan helper as `TARGET`:
- **Changed files (default):** `bash .claude/skills/tag/scripts/scan_untagged.sh` — files changed vs
  `origin/main` (or `… <git-ref>`). Use when tagging the current branch's work before a PR.
- **A single file (even if unchanged):** `bash .claude/skills/tag/scripts/scan_untagged.sh <path/to/File.kt>`
  — tag that one file regardless of git status. Use when onboarding or re-tagging a specific file.
- **A directory / module (even if unchanged):** `bash .claude/skills/tag/scripts/scan_untagged.sh <path/to/dir>`
  — every code file under it, regardless of git status.

If the developer names a file or module ("tag `LunchMenuDataSource.kt`", "tag the `data` package"),
use that path as the target. With no target, default to changed files.

**Skip files that need no tagging.** For each in-scope file, if it is already fully covered by fences
(no unfenced code regions remain), leave it untouched and move on — do not add redundant tags or
re-open the DDR prompt for it.

## Principles (do not violate)
- **Operate silently, with one exception.** Apply tags directly — no narration, no rationale, no
  confirmation, no summary. The ONLY allowed interaction: ONE batched DDR prompt covering all
  `HUMAN-AUTHORED` regions at once (ids, or "skip all" → `DDR: none`). Nothing else.
- **Never modify, remove, or move an existing fence or its contents.** Existing fences are immutable.
- **Only tag UNFENCED code**, and only as `HUMAN-AUTHORED` or `BOILERPLATE` (never an AI tag).
  Unfenced ⇒ human.
- **Do not change code logic.** Only insert comment fences.
- **If unfenced code clearly looks AI-generated or vendor-derived** (the agent forgot to fence it, or it
  was copied from a datasheet/official vendor repo), leave it untagged for the checker to catch — do not
  tag it HUMAN-AUTHORED. Still stay silent.

## Classification (for unfenced/human regions)
- **BOILERPLATE** — standard, non-patentable constructs (CRUD, getters/setters, config, plumbing,
  trivial math). No DDR. Record `Developer:`.
- **HUMAN-AUTHORED** — human-conceived, potentially patentable / novel / domain-specific logic.
  DDR is **optional but explicit**: prompt for one; record `DDR: <id>` if provided, or `DDR: none` if
  the developer opts out (simple human code may need no record). Code implementing an approach the
  developer **selected from AI-presented options** should carry a real DDR (alternatives + rationale).

## Procedure (silent — no output)
0. **Resolve scope.** Run `scan_untagged.sh` with the developer's TARGET (file, dir, or none → changed).
   Process each listed file; skip files already fully fenced with no unfenced regions.
1. **Parse the file into regions** by scanning for `PROVENANCE-BEGIN:`/`PROVENANCE-END:` fences and any
   top-of-file `PROVENANCE:` header. Code not inside a fence is an UNFENCED (human) region.
2. **Leave every existing fence untouched.**
3. **Tag each unfenced region** using defaults, directly (no confirmation): trivial/standard →
   BOILERPLATE; domain/algorithmic/novel → HUMAN-AUTHORED.
4. **Insert a fence** around each region in the file's native comment syntax.
5. **Merge, don't proliferate:** extend an adjacent same-tag fence rather than adding a second; never
   merge across a different-tag fence or across other code.
6. **Fill fields:** `Developer:` (`git config user.name`), `Date:` (today, ISO-8601), and a `Trace:` that
   is **always present** — use the developer's work-item/ticket id if known, otherwise auto-mint one:
   `T-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c6)` (e.g. `T-k7d2q9`). Reuse the same trace id in
   the region's DDR so code, DDR, and the session share one id. Never omit `Trace:` and never ask for it.
7. **DDRs for HUMAN-AUTHORED regions — ONE batched prompt.** For each such region, offer clear choices
   (not two ways to type the same thing):
     - **Link an existing DDR** → enter its `DDR-<id>`.
     - **Not a design decision** → downgrade the region to `BOILERPLATE` (no DDR). Use this when there
       is no real rationale (e.g. a trivial/test method) instead of inventing one.
     - **Record a new decision** → the developer gives the rationale in their own words; append a new
       `DDR-<n>` entry, link it, and **sign it** (see *Sign the decision* below).
     - **Skip / opt out** → `DDR: none`.
   Fall back to `DDR: TBD` only when non-interactive. Never fabricate a rationale.
8. **Emit nothing else** — no summary, no rationale beyond the DDR prompt(s).

## Comment syntax by extension
`//` → kt, kts, java, js, ts, tsx, jsx, go, c, cc, cpp, cs, rs · `#` → py, sh, rb · `--` → sql, hs

## Fence format (example, `//`-style)
```
// PROVENANCE-BEGIN: HUMAN-AUTHORED  Developer: <name>  Date: <ISO-8601>  Trace: <id>  DDR: <ref>
...the human-written code...
// PROVENANCE-END: HUMAN-AUTHORED
```
Use `BOILERPLATE` (omit `DDR:`) for standard constructs.

## Decision records (DDR) — one file per decision, collision-free id
DDRs live as **one file per decision** under `docs/ddr/` (default; `DDR_DIR` in `.claude/throughmark/config`).
File-per-record lets multiple developers create DDRs concurrently with **no merge conflicts**. A legacy
single `docs/DDR.md` is still read if present.

**Mint the id locally and randomly — never a global "next number"** (a running counter collides across
branches). Use `DDR-` + 6 random base36 chars, e.g. `DDR-k7d2q9`:
`id="DDR-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c6)"`. Once minted, an id is permanent and
never renumbered, so code `DDR:` references survive every merge. Write the record to
`docs/ddr/DDR-<id>.md`:
```
## DDR-<id> — <title>
Date: <ISO>  Developer: <git user.name>  Trace: <work-item / trace id>
Options considered: <the options that were on the table>
Chosen: <the option>
Rationale: <the developer's own words — never fabricated>
Conceived-by: human
```
When the developer selects an AI-presented option, **create the file** `docs/ddr/DDR-<id>.md`: fill the
factual parts (options, choice, developer, trace, date) and the developer's stated reason from the
session, then set `DDR: DDR-<id>` in the code fence. If no reason was stated, ask — do not invent one.
**The `Rationale` must be the developer's own words and `Conceived-by: human` records that origin.** The
gate requires a non-empty `Rationale`, `Conceived-by: human`, and a globally unique id. Prefer seeding
`Trace:` from the work-item/ticket key (globally unique) so traces don't collide between developers.

## Sign the decision (item 2 — non-repudiable conception)
After you WRITE a new `docs/ddr/DDR-<id>.md`, sign it so the record is cryptographically bound to the
developer who conceived it — this is what lets the client enforce signed human conception at the gate:

```
bash .claude/throughmark/bin/sign_ddr.sh docs/ddr/DDR-<id>.md --trace <trace>
```

It writes `docs/ddr/DDR-<id>.md.att.json` and, on first use, registers the developer's SSH key in
`.claude/throughmark/allowed_signers`. **Commit the `.att.json` together with the DDR.** Do it silently as
part of recording the decision (not a separate prompt). Best-effort: with no SSH signing key it prints how
to set one and leaves the DDR unsigned — signing is advisory until the client turns on `ATTEST_ENFORCE`.

## Do NOT
- Narrate, explain, or summarize the tagging — operate silently (the single per-region DDR prompt for
  HUMAN-AUTHORED is the only allowed interaction).
- Use git history to decide AI-vs-human authorship (fences are the source of truth).
- Touch, retag, or move existing fences, or alter code behavior.
- Wrap unfenced code in an AI tag; human unfenced code becomes HUMAN-AUTHORED (or BOILERPLATE if
  genuinely standard).
- Apply or alter the vendor-enablement tags `THIRD-PARTY-OSS` / `VENDOR-DOC`; like the AI tags they are
  written by the coding agent at generation time — treat them as existing fences and leave them untouched.

*Authoring aid for the clean-room process. Not legal advice. The independent provenance-tag-checker still audits.*
