# AGENTS

## Project Specific Rules

- Stack detection: this repository is a SwiftPM library (`Package.swift`, `.swift` sources, Swift tests under `Tests/`).
- Keep changes minimal and consistent with current library design (`Session`, `Processor`, `ProcessorGroup`, `Resource` flow).
- Prefer preserving public API compatibility unless the task explicitly requests a breaking change.
- For behavior changes, add or update focused tests in `Tests/JSONSessionTests`.
- Validate with `swift test` when code or tests change; report any skipped validation and why.
- Relevant local guidance:
  - [Swift](Extras/Documentation/Guidelines/Swift.md)
  - [Testing](Extras/Documentation/Guidelines/Testing.md)

## Standard Rules

- Follow red/green TDD when practical; otherwise use the validation workflow in `Extras/Documentation/Guidelines/Testing.md`.
- Write good code: correct, minimal, maintainable, tested, and updated documentation (`Extras/Documentation/Guidelines/Good Code.md`).
- Apply these engineering principles:
  - KISS
  - YAGNI
  - DRY (thoughtfully)
  - Make Illegal States Unrepresentable
  - Dependency Injection
  - Composition Over Inheritance
  - Command-Query Separation
  - Law of Demeter
  - Structured Concurrency
  - Design by Contract
  - Idempotency
- Change strategy:
  - Prefer focused diffs and root-cause fixes.
  - Preserve existing architecture/style unless change is necessary.
  - Avoid unrelated refactors.
- Core workflow:
  1. Understand request boundaries.
  2. Inspect relevant code/docs before editing.
  3. Apply the smallest coherent change.
  4. Add/update tests where feasible.
  5. Run relevant validation checks.
  6. Report what changed, what was validated, and residual risk.
- Engineering guardrails:
  - Prioritize correctness, clarity, and maintainability.
  - Keep interfaces explicit and small.
  - Avoid hidden coupling/surprising side effects.
  - Do not add dependencies without clear justification.
  - Never expose or commit secrets.
- Comments and documentation:
  - Add concise intent-focused documentation comments for types, methods/functions, and members/properties.
  - Keep inline comments sparse and only for non-obvious constraints/logic.
  - Keep docs aligned with actual behavior.
- Source quality:
  - Prefer primary sources (official docs/specs/first-party repos).
  - Use secondary sources only as supporting context and verify before relying.
- Relevant local guidance:
  - [Principles](Extras/Documentation/Guidelines/Principles.md)
  - [Testing](Extras/Documentation/Guidelines/Testing.md)
  - [Trusted Sources](Extras/Documentation/Guidelines/Trusted Sources.md)
  - [Good Code](Extras/Documentation/Guidelines/Good Code.md)
  - [Swift](Extras/Documentation/Guidelines/Swift.md)

---

Regenerate this file regularly using `~/.local/share/agents/REFRESH.md` with `~/.local/share/agents/COMMON.md` and relevant modules in `~/.local/share/agents/instructions/`.
