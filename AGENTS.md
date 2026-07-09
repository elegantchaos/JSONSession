## Project Specific Rules

- This repository is a SwiftPM library for JSON REST API sessions that use bearer-token authentication.
- Keep the package focused on transport, decoding, resource resolution, and polling primitives.
- Preserve structured-concurrency semantics and keep caller-owned scheduling/cancellation policy explicit.
- Validate code changes with `swift test` and report any skipped validation.

## Standard Rules

- Always write good, modern, idiomatic code.
- Prefer fixing root causes over layered workarounds.
- Keep interfaces explicit and intentionally small.
- Avoid hidden coupling and surprising side effects.
- Write documentation to reflect the current state.
- Apply DRY, single-source-of-truth, KISS, YAGNI, make-illegal-states-unrepresentable, dependency injection, composition over inheritance, command-query separation, Law of Demeter, structured concurrency, design by contract, and idempotency.
- Understand request boundaries, inspect relevant code and docs before editing.
- Match change scope to the request: keep focused fixes small and coherent; use codebase-wide cleanup when the task is cleanup, review, modernisation, or consistency work.
- Use red/green TDD for non-UI code.
- Add or update tests for behavior changes.
- Create previews for UI code if UI code is introduced.
- Run the narrowest validation that proves the change first, then broaden to relevant project checks.
- Report skipped validation with the reason, validation gaps, and residual risks.
- Use trusted primary sources for technical decisions.
- Use portable path references in docs and guidance. Prefer repository-relative paths for files in this repository and `~/...` paths for shared resources outside it. Avoid machine-specific absolute paths.
- Never expose or commit credentials or secrets.
- Do not perform irreversible destructive actions without explicit approval. Reversible tracked-file deletions do not require extra approval beyond the user's request.
- Avoid unrelated refactors during focused tasks, but note them as follow-up work when needed.
- If unexpected workspace changes appear, pause and confirm direction.
- Do not repeatedly advertise that the agent is verifying instead of guessing; that should be treated as default competence and only called out when there is real uncertainty or risk.

## Skills

- Follow the `coding-standards` skill for all coding.
- Use the `swift` skill when working on Swift code.
- Use the `swift-concurrency-pro` skill when working on concurrent Swift code.
- Use the `swift-testing-pro` skill when working on Swift tests.
- Use the `validation-flow` skill when validating code changes.
- Use the `codex-git` skill for git operations.
- Use the `codex-github` skill for GitHub operations.

To refresh this file, use the `refresh` skill.
