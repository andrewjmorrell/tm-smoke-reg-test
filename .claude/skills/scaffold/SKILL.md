---
name: scaffold
description: Generate the standard, non-inventive plumbing for a new module — file I/O, HTTP handlers, CRUD, serialization, config/logging/error handling, DI wiring — as BOILERPLATE-fenced code, and deliberately STOP at the novel core, leaving a HUMAN-AUTHORED placeholder for the developer to conceive. Keeps clean-room inventorship intact: the assistant builds the scaffolding, the human builds the invention. Never fills in domain/novel logic on its own.
---

# scaffold — generate the boilerplate, defer the invention

## When
Starting a new module, endpoint, or service and you want the standard structure in place fast without the
assistant reaching into novel or domain-specific logic.

## Procedure
1. Ask the developer for the module's shape in functional terms (inputs, outputs, where it plugs in). Do
   NOT ask them to name a product or repo to copy.
2. Generate ONLY standard, first-principles plumbing and fence it `BOILERPLATE`: file/network I/O, HTTP
   routing, request/response validation and serialization, CRUD/migrations, config, logging, error
   handling, dependency wiring, standard data structures.
3. Where the module's distinctive behavior would go — scoring/ranking, domain rules, novel algorithms or
   protocols, optimization/caching that makes the product *better* — do NOT write it. Leave a fenced
   placeholder:
   ```
   // PROVENANCE-BEGIN: HUMAN-AUTHORED  Developer: <name>  Trace: <id>  DDR: <ref>
   // TODO(human): <one line naming the decision to be made here>
   // PROVENANCE-END: HUMAN-AUTHORED
   ```
   and, for a real choice among approaches, present 2–3 options with trade-offs and let the developer pick
   (feed the choice to `ddr-draft`).
4. Every fence carries `Agent:`, `Date:`, `Module:`, `Trace:` per the guardrail.

## Rules
- Never fill a novel/domain placeholder yourself — that is the human's conception. When unsure whether a
  piece is boilerplate or invention, choose the stricter tag and ask.
- No web browsing, no copying from any named source.

*Authoring aid. Provenance fences are checked at the gate; placeholders left HUMAN-AUTHORED will fail until the human fills and records them.*
