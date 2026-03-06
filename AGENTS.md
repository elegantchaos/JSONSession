# AGENTS

## Project Specific Rules

- This repository is a SwiftPM library (`Package.swift`, Swift sources under `Sources/`, Swift tests under `Tests/`).
- Validate code changes with `swift test` and report any skipped validation.
- Use stack-local guidance when needed:
  - [Swift](Extras/Documentation/Guidelines/Swift.md)
  - [Testing](Extras/Documentation/Guidelines/Testing.md)

## Standard Rules

- Use red/green TDD for non-UI code; create previews for UI code; and follow the validation workflow in [Testing](Extras/Documentation/Guidelines/Testing.md).
- Always write good code: correctness, minimalism, maintainability, test coverage, and documentation updates ([Good Code](Extras/Documentation/Guidelines/Good Code.md)).
- Apply core engineering principles from [Principles](Extras/Documentation/Guidelines/Principles.md):
  - Required: DRY, Single Source of Truth.
  - Preferred: KISS, YAGNI, Make Illegal States Unrepresentable, Dependency Injection, Composition Over Inheritance, Command-Query Separation, Law of Demeter, Structured Concurrency, Design by Contract, Idempotency.
- Change strategy:
  1. Understand request boundaries.
  2. Inspect relevant code/docs before editing.
  3. Apply the smallest coherent change set.
  4. Add/update tests for behavior changes.
  5. Run relevant validation checks.
  6. Report changes, validation status, and residual risk.
- Engineering guardrails:
  - Keep interfaces explicit and intentionally small.
  - Avoid hidden coupling and surprising side effects.
  - Do not add dependencies without clear justification.
  - Never expose or commit credentials/secrets.
- Documentation and comments:
  - Keep docs accurate and aligned with behavior.
  - Add concise intent-focused documentation comments for types/functions/members.
  - Keep inline comments sparse and only for non-obvious logic/constraints.
- Source quality and research: prefer primary sources and follow [Trusted Sources](Extras/Documentation/Guidelines/Trusted Sources.md).
- Safety and discipline:
  - Avoid unrelated refactors during focused tasks.
  - Do not perform destructive actions without explicit approval.
  - If unexpected workspace changes appear, pause and confirm direction.

---

To refresh this file, use the refresh-agents skill.
