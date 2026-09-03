# Design Decision Records (DDR)

Human-conception evidence. **One file per decision** in this directory (`docs/ddr/DDR-<id>.md`), so
multiple developers create records concurrently with no merge conflicts. IDs are minted **randomly**
(`DDR-` + 6 base36 chars, e.g. `DDR-k7d2q9`) — never a running counter — so they never collide across
branches and are never renumbered. Code references a record by id, e.g.
`// PROVENANCE-BEGIN: HUMAN-AUTHORED … DDR: DDR-k7d2q9`.

Each record is auto-drafted from the AI session **except the Rationale**, which must be the developer's
own words, and `Conceived-by: human`, which records that origin.

Record format (one per file):
```
## DDR-<id> — <title>
Date: <ISO>   Developer: <git user.name>   Trace: <work-item / trace id>
Options considered: <options that were on the table>
Chosen: <the option>
Rationale: <the developer's own words — never fabricated>
Conceived-by: human
```

The gate requires each referenced id to resolve to a record with a non-empty Rationale,
`Conceived-by: human`, and a **globally unique** id. Seed `Trace:` from your work-item/ticket key so
traces stay unique between developers. A legacy single `docs/DDR.md` is still read if present.
