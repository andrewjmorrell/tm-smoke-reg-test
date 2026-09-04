---
name: explain-finding
description: Explain a red ThroughMark gate check and fix it in THIS repo. Paste a failing throughmark-provenance / throughmark-audit / throughmark-sources / throughmark-validity / throughmark-attestations output (or a finding code like GUARDRAIL-MISSING, PROVENANCE-UNTAGGED, SOURCE-REQUIRED, DDR-UNSIGNED, MALFORMED-FENCE) and the skill maps it to the exact file/fence/DDR and walks the remediation. Use when a PR check is red and you're unsure why.
---

# explain-finding — turn a red gate check into a guided fix

## When
A ThroughMark check on your PR is red and the finding text is terse. Paste it here.

## Procedure
1. Identify the check + finding code from what the developer pasted.
2. Explain in one or two sentences what it means and WHY the gate raised it.
3. Locate it in this repo — the `file:line`, fence, or DDR it points at. If the finding lacks a location,
   run `bash .claude/skills/validate/scripts/validate_scan.sh` to cross-reference.
4. Walk the exact fix, handing off to the right skill: tagging → `tag`; a DDR decision → `validate` /
   `ddr-draft`; a citation → `cite`; signing a DDR → `sign_ddr.sh`; a stale validity → a qualified
   reviewer re-Approves (not the author).
5. Offer to run `validate` to confirm the branch is clean before re-pushing.

## Reference — common findings
- **SOURCE-REQUIRED** (regulated): AI-DRAFTED/FLAGGED block lacks `Sources:` → `cite`.
- **GUARDRAIL-MISSING / GUARDRAIL-SECTION**: the repo's guardrail file is absent or missing a required
  section → repair/reinstall the kit guardrail.
- **DDR-UNSIGNED / DDR-BAD-SIGNATURE**: a referenced DDR isn't signed, or was edited after signing →
  `sign_ddr.sh` (re-sign after ANY edit).
- **PROVENANCE-UNTAGGED**: human code with no fence → `tag`.
- **MALFORMED-FENCE / BAD-TAG**: a BEGIN without an END, or an unknown tag → fix the fence.
- **throughmark-validity pending/failure**: needs a qualified reviewer's web Approve (or `signoff`) — not
  the author.

*Authoring aid. Explains and helps fix; the gate remains the authoritative check.*
