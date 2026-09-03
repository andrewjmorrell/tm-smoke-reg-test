<!-- ThroughMark operational rules — auto-applied via the CLAUDE.md / GEMINI.md import. Workflow tooling
     that sits ON TOP of the clean-room guardrail; it never relaxes a guardrail rule. Unlike the guardrail,
     editing this file does not require counsel sign-off — but keep it consistent with the guardrail. -->

## Trace ids — automatic (never ask the developer for one)

Every provenance fence and DDR carries a `Trace:` id — the join key linking code -> decision record ->
commit -> PR -> the AI session behind it. Supply it yourself; the developer should never type one. Resolve
the id in THIS order:

1. **Reuse an id already in the code.** BEFORE minting anything, look at the block you are creating or
   editing: if it — or the file / region it belongs to — already carries a `Trace:` id in an existing
   fence, REUSE that id. The id lives in the code, not in your memory, so read it back and continue it.
   This is what keeps one piece of work on ONE trace across a `/clear`, a context compaction, a new
   session the next day, or a different developer's machine. Only move past this step if there is
   genuinely no existing trace on the code you're touching.
2. **Use the developer's work item.** If the developer names a ticket (e.g. `JIRA-1420`, `TM-42`), use it verbatim.
3. **Mint one.** For genuinely new, untraced work, mint `T-<UTC date YYYYMMDD>-<4 random base32 chars>`
   (e.g. `T-20260726-K7Q2`), say it once ("Trace for this change: T-…"), and reuse that SAME id on every
   fence and DDR for this change.

Never leave a fence without a Trace. Because the id is anchored in the code, the fenced code and the
session transcript share it — which is what binds the session to the code with no manifest, and what
survives the developer clearing context mid-change.

## Keep provenance tags current as the code evolves

A block's authorship can shift over a long back-and-forth (draft -> tweak -> rewrite). Keep the fence tag
honest as you go rather than leaving a stale one — but respect who is allowed to assert what:

- **Your own classifications, you maintain live.** Each time you materially rewrite a block, re-evaluate
  and update its tag among `BOILERPLATE` / `AI-DRAFTED` / `FLAGGED` to reflect what it is NOW. These are
  your labels for your own output; keep them accurate turn by turn.
- **`HUMAN-AUTHORED` is anchored to a human decision — never your own judgment.** Tag a block
  `HUMAN-AUTHORED` only at the moment the developer actually conceives it: they select one of the options
  you offered, or they specify the novel logic themselves. Then tag it `HUMAN-AUTHORED`, auto-fill
  `Developer:`, and draft the DDR from that exchange (per the guardrail). NEVER relabel your own draft as
  human-authored on your own assessment — that would manufacture the provenance and destroys its value.
- **The human confirms at the end.** For gradual co-authoring with no single decision point, leave the
  block `AI-DRAFTED` and have the developer confirm final authorship via the `tag` skill before the PR —
  that human confirmation is the authoritative record, and `AI-DRAFTED` requires human transformation
  before merge anyway.

The clean-room guardrail imported alongside this file is always in force; the developer never has to ask
you to follow it, and you apply it automatically to all covered work.
