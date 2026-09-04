---
name: update-ddr
description: Update the content of an existing Design Decision Record (DDR) — its rationale, options, or chosen approach. Invoke with a FILE (iterate every DDR referenced by that file's provenance fences, offering to update each and letting the developer stop before finishing all) or a DDR ID (update just that one, or cancel). The rationale is always the developer's own words — never fabricated — and `Conceived-by: human` is preserved. Does NOT create new DDRs or tag code (use the `tag` skill for that).
---

# update-ddr — revise an existing decision record

## When to run
When a decision's recorded rationale needs to change — the developer refined their reasoning, picked a
different option, or the original entry was thin. Use this to edit existing `DDR-<n>` entries in the
decision log. It does not create DDRs and does not touch code fences.

## Inputs (one of)
- **A file** (e.g. `update-ddr app/.../LunchMenuDataSource.kt`) → walk every DDR the file references.
- **A DDR id** (e.g. `update-ddr DDR-07`) → update that single entry.

DDRs are **one file per decision** under `DDR_DIR` (default `docs/ddr/`, from `.claude/throughmark/config`); a
legacy single `docs/DDR.md` is still read if present. To find the file that holds an id for editing:
`bash .claude/skills/update-ddr/scripts/ddr_tool.sh file <id>` → edit that file in place.

## Non-negotiable rules
- **Never fabricate rationale.** The `Rationale` is the developer's own words. If they don't provide
  new wording, keep the existing text — do not invent or "improve" it.
- **Preserve `Conceived-by: human`.** Human conception is the point of the record; never drop or weaken it.
- **Edit only the named entry/entries.** Never alter other DDRs, and never edit code files or fences —
  the `DDR: <id>` links in code stay as they are (the id is unchanged).
- **Update `Date:`** to today when you change an entry, and leave the `DDR-<n>` id and `Trace:` intact.
- **Apply directly — no extra approval.** Show the current entry, take the developer's new wording, and
  write it immediately. Do not ask them to approve the resulting edit/diff; the wording they supplied is
  the go-ahead. (The only interaction is choosing update/skip/stop and giving the new text.)

## Procedure — FILE mode
1. **List the file's DDRs:** `bash .claude/skills/update-ddr/scripts/ddr_tool.sh ids-in <file>`
   (returns the `DDR-<id>`s referenced by that file's fences, in file order; `none`/`TBD` are ignored).
   If none, say so and stop.
2. **Iterate in order.** For each id:
   a. Show the current entry: `bash .claude/skills/update-ddr/scripts/ddr_tool.sh show <id>`.
   b. Ask the developer what to do: **update this one** (they provide the new rationale / options /
      chosen in their own words), **skip this one** (leave unchanged, go to next), or **stop** (done —
      do not process remaining DDRs).
   c. If update: locate the record's file (`ddr_tool.sh file <id>`), rewrite that entry's changed fields
      there, keep `Conceived-by: human`, refresh `Date:` to today. Leave everything else intact. **Then re-sign the record** (see *Re-sign after editing*).
3. **Stop immediately when the developer chooses stop** — the remaining DDRs in the file are left as-is.

## Procedure — ID mode
1. Show the current entry: `ddr_tool.sh show <id>`. If the id isn't in the log, say so and stop.
2. Ask the developer for the update (new rationale / options / chosen, in their own words) **or cancel**.
3. If cancel → make no change. Otherwise apply the edit (preserve id/Trace/`Conceived-by: human`,
   refresh `Date:`). **Then re-sign it** (see below).

## Re-sign after editing (item 2 — REQUIRED)
Editing a DDR changes its bytes, which **invalidates any existing signature** — the gate would report
`DDR-BAD-SIGNATURE`. So immediately after writing an updated entry, re-sign that record:

```
bash .claude/throughmark/bin/sign_ddr.sh <the-DDR-file-you-edited>
```

This refreshes `<file>.md.att.json`; commit it with the edit. Best-effort (no SSH signing key → it prints
guidance and leaves the record unsigned). Skip only if the record had no `.att.json` and the developer is
not signing.

## Entry format (unchanged — edit fields in place)
```
## DDR-<n> — <title>
Date: <ISO>  Developer: <git user.name>  Trace: <work item>
Options considered: <options>
Chosen: <option>
Rationale: <developer's own words — never fabricated>
Conceived-by: human
```

## Do NOT
- Create a new DDR (that's the `tag` skill's job when a decision is first recorded).
- Fabricate, paraphrase, or "polish" the developer's rationale.
- Touch code, fences, or any DDR other than the one(s) requested.
- Change a DDR's id or remove `Conceived-by: human`.

*Authoring aid for the clean-room process. Not legal advice. The independent provenance-tag-checker and
gate still audit that every HUMAN-AUTHORED fence resolves to a real, human-conceived DDR.*

## Signing (works inside an IDE plugin — no TTY, no agent needed)
DDR conception signing runs where you run the skill — a Claude plugin inside your IDE (Antigravity, VS
Code, Android Studio). That process has no terminal and usually no ssh-agent, so signing does **not**
require either: `sign_ddr.sh` picks the first key that can sign with no prompt, and if none exists it
**auto-provisions a dedicated, passphrase-less, signing-only key** (`~/.ssh/throughmark_ed25519`) and
registers its public key in `allowed_signers` for the gate. So signing normally just works.

If signing ever fails, the DDR **content is still saved correctly** — only the `<ddr>.md.att.json`
signature is missing; re-run `bash .claude/throughmark/bin/sign_ddr.sh <ddr-file>`. Signing is advisory
until the client enables ATTEST_ENFORCE. Hardened alternative: set `TM_SIGN_NO_AUTOKEY=1` to require an
agent-loaded or hardware key instead of the auto-provisioned one (then load your key with `ssh-add`).
