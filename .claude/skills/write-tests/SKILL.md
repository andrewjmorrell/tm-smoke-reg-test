---
name: write-tests
description: Generate tests, mocks, and fixtures for existing code as BOILERPLATE-fenced test scaffolding — covering the behavior the human logic is supposed to exhibit, without re-deriving or leaking that logic into the test. Use after a module (including its HUMAN-AUTHORED core) exists and you want coverage. Test scaffolding is standard boilerplate; it never encodes the novel algorithm itself.
---

# write-tests — coverage as BOILERPLATE test scaffolding

## When
A module exists (its novel parts already conceived by the human) and you want unit/integration tests,
mocks, or fixtures.

## Procedure
1. Read the module's public contract (signatures, documented behavior) — treat it as a black box.
2. Generate tests, mocks, fixtures, and harness code and fence it `BOILERPLATE` (test scaffolding is
   standard). Cover: happy path, edge/boundary cases, error handling, and the behaviors the developer says
   matter.
3. For behavior driven by HUMAN-AUTHORED logic, assert on observable inputs→outputs from the contract — do
   NOT reimplement or paraphrase the algorithm inside the test (that would leak novel logic into an
   unfenced/boilerplate region).
4. Run the tests; report failures plainly for the developer to resolve.

## Rules
- Tests are `BOILERPLATE`. If writing a meaningful test would require re-deriving the novel algorithm,
  stop and ask the developer for the expected values instead of computing them yourself.
- No web browsing; use only the module's public API.

*Authoring aid. Coverage and correctness remain the developer's call.*
