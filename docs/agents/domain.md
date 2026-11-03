# Domain Docs

How engineering skills should consume this repo's domain documentation.

## Before exploring, read these

- `GLOSSARY.md` at the repo root.
- `docs/adr/`: ADRs that touch the area being explored.

If these files do not exist, proceed silently. Do not flag their absence or suggest creating them upfront; `/domain-modeling` creates them when terms or decisions are resolved.

## Layout

This is a single-context repo: one root `GLOSSARY.md` and system-wide ADRs in `docs/adr/`.

## Use the glossary's vocabulary

When output names a domain concept (for example in an issue title, refactor proposal, hypothesis, or test name), use the term as defined in `GLOSSARY.md`. If a needed concept is absent, reconsider whether it is project vocabulary or note the gap for `/domain-modeling`.

## Flag ADR conflicts

If output contradicts an existing ADR, surface the conflict explicitly rather than silently overriding it.
