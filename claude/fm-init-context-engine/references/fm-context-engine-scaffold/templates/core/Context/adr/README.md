# Architecture Decision Records

Numbered, append-only record of architectural decisions. ADRs are never renumbered or deleted. A decision that replaces an earlier one creates a new ADR and updates the earlier ADR's status to `Superseded by ADR-NNNN`.

## Format

Each ADR uses the Nygard format — Status, Context, Decision, Consequences (Positive / Negative), Alternatives Considered. Extensions (References, Migration approach) are allowed when relevant.

## Creating a new ADR

Pick the next unused number, zero-pad to 4 digits, and create `NNNN-<kebab-slug>.md`. The `/new-adr` slash command automates this.

## Index

| # | Title | Status |
| --- | ----- | ------ |
| [0001](0001-adopt-context-engine.md) | Adopt the context-engine documentation and automation system | Accepted |
