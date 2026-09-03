---
name: validity-signoff
description: Record a regulated validity sign-off on a pull request — a qualified reviewer's attestation that the AI-assisted change was checked against its cited source and is valid (or invalid / valid-with-conditions). Guides the reviewer through an actual review, enforces separation of duties (reviewer must NOT be the PR author), then posts the required `throughmark-validity` check and writes an immutable sign-off record. Regulated mode only. In production, prefer approving the PR in the GitHub web UI — this skill is the terminal-side path for reviewers who work from Claude.
---

# validity-signoff — a qualified reviewer signs off a PR's validity

## When to run
In **regulated** mode, every change needs a human **validity sign-off** before it can merge: a qualified
reviewer attests that the AI-assisted output was checked against its **cited source** and is valid. This is
the required `throughmark-validity` check. Run this skill when you are that reviewer and you are signing off
a specific PR from the terminal.

**Prefer the web path when you can.** A qualified reviewer can simply click **Approve** on the PR in GitHub
and the gate records the sign-off automatically — no terminal. Use this skill when you are reviewing from
Claude / the CLI, for scripted sign-off, or to attach a non-repudiable SSHSIG attestation.

## The one rule that cannot bend
**The reviewer is the human, not the assistant.** This skill does not decide validity. You (the reviewer)
read the change, judge it against the cited source, and state the verdict in your own words. The skill only
records what you decided. Two hard constraints, both enforced by the helper:
- **Separation of duties** — the signed-in reviewer must **not** be the PR author. If they are, stop.
- **A cited source is required** — you must say *what you checked the change against* (a spec, standard,
  reference, SOP, edition/section). "Looks fine" is not a sign-off.

## Inputs
- A **PR number** (required), e.g. `validity-signoff 42`.
- Optionally `--repo <owner/name>` if you are not inside the repo's working copy.

## Procedure
1. **Establish context.** Run:
   `bash .claude/skills/validity-signoff/scripts/signoff_tool.sh context <pr>`
   It prints `repo`, `author`, `reviewer` (whoever is signed into `gh`), `head_sha`,
   `separation_of_duties_ok`, and the `sink_bucket`.
   - If `separation_of_duties_ok=no`, **stop**: the signed-in account is the PR author. Tell the reviewer
     to sign off as a different, qualified account (or `gh auth switch`). Never work around this.
   - If `sink_bucket` shows `<none…>`, warn that the immutable record can't be written from here (the
     commit status will still post); the reviewer may prefer the web Approve path, which always records.

2. **Actually review the change.** Do not skip to signing.
   - Show the diff: `gh pr diff <pr>` (or `--repo <slug>`), and read the changed code.
   - Identify the **cited source(s)** the change claims: the `Sources:` lines in the provenance fences and
     any DDR the fences reference (`docs/ddr/<id>.md`). Open and read them.
   - Help the reviewer compare the change against that source: does the code do what the source says, and
     nothing the source forbids? Surface anything that doesn't line up. If there is **no** cited source on
     AI-assisted code, that is itself a problem — the `throughmark-sources` check should already flag it;
     the correct verdict is likely `invalid` or `conditions` until a source is cited.

3. **Get the reviewer's verdict — in their own words.** Ask for:
   - **verdict**: `valid` | `invalid` | `conditions` (valid only with the noted conditions),
   - **source**: what they checked it against (e.g. `ICH E6(R2) §5.1`, `Kotlin stdlib reference`),
   - optional **source-version** (edition/rev), **role** (their qualification, e.g. "senior clinical SME"),
     and **notes**.
   Never fabricate any of these. If the reviewer won't state a verdict and a source, do not sign off.

4. **Record the sign-off.** Run:
   ```
   bash .claude/skills/validity-signoff/scripts/signoff_tool.sh record <pr> \
     --verdict <valid|invalid|conditions> --source "<what you checked against>" \
     [--source-version "<edition/rev>"] [--role "<your qualification>"] [--notes "<...>"]
   ```
   The helper re-checks separation of duties, writes an immutable record to the WORM sink
   (`signoffs/<repo>/<pr>/<head_sha>.cli-<reviewer>.json`, create-only), optionally attaches an SSHSIG if
   the reviewer has an SSH signing key (`TM_SIGN_KEY` or `git config user.signingkey`), and posts the
   `throughmark-validity` commit status. A `valid` verdict posts **success** (PR becomes mergeable); any
   other verdict posts **failure** (the PR stays blocked, as it should).

5. **Confirm the outcome** to the reviewer: the check state (green/red), where the record was written, and —
   for a non-`valid` verdict — that the PR is intentionally still blocked. If the sink bucket was absent,
   remind them the record wasn't captured and the web Approve path (or setting `SINK_BUCKET`) would fix that.

## Staleness (expected, not a bug)
A sign-off is bound to the exact **head SHA** reviewed. If a new commit is pushed, `throughmark-validity`
disappears on the new SHA and the PR re-blocks (GitHub also dismisses the prior review). That is the gate
working: re-review and re-sign the new head.

## Do NOT
- Sign off your own PR, or help someone bypass the reviewer-≠-author rule.
- Invent or "improve" the reviewer's verdict, source, role, or notes.
- Mark a change `valid` with no cited source, or when the diff doesn't match the source.
- Edit code, DDRs, or provenance fences from this skill — sign-off only records a judgment.

*Process aid for the regulated clean-room workflow. Not legal advice. The commit status, the immutable
sink record, and (if signed) the SSHSIG attestation are the independent audit evidence; branch protection
requires this check before merge.*
