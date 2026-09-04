---
name: ddr-draft
description: Create and sign a Design Decision Record (DDR) for a human-conceived decision — interview the developer for the options they weighed, the option they chose, and WHY in their own words, then write a one-file DDR under docs/ddr/ with a fresh random id and run sign_ddr.sh to attach the conception attestation. Use when tag/scaffold/validate flags a HUMAN-AUTHORED block that needs a DDR. The rationale is always the developer's words; never fabricated. (To edit an existing DDR, use update-ddr.)
---

# ddr-draft — record a human decision as a signed DDR

## When
A HUMAN-AUTHORED block needs a decision record — `tag`, `scaffold`, or `validate` reported `DDR-NEEDED`, or
the developer just made a novel/domain choice worth capturing. This CREATES a new DDR; to revise an
existing one use `update-ddr`.

## Procedure
1. **Interview the developer** (this is the whole point — capture human conception):
   - What was the decision / what does this block do?
   - What options were on the table? (2–3)
   - Which did you choose?
   - **Why — in your own words?** (the rationale must be theirs, not yours)
2. Mint a fresh random id and create one file per decision under `DDR_DIR` (default `docs/ddr/`), following
   `DDR.template.md`:
   ```
   id="DDR-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c6)"
   ```
   Write `docs/ddr/$id.md` with the record: `## <id> — <title>`, `Date:` (ISO), `Developer:` (git
   user.name), `Trace:` (work-item id), `Options considered:`, `Chosen:`, `Rationale:` (developer's own
   words), `Conceived-by: human`.
3. Point the code fence at it: the block's `DDR:` field becomes `$id`.
4. **Sign it:** `bash .claude/throughmark/bin/sign_ddr.sh docs/ddr/$id.md --trace <id>` and commit the
   `.att.json` ALONGSIDE the DDR.

## Rules
- NEVER write the Rationale yourself or infer it — if the developer can't state why, the decision isn't
  ready; leave the block flagged rather than fabricate. This is the one rule that makes the DDR evidence of
  human inventorship.
- `Conceived-by: human` always. One decision per file. Ids are random base36, never a running counter.

*Authoring aid. The gate requires each referenced id to resolve to a record with a non-empty Rationale and Conceived-by: human.*

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
