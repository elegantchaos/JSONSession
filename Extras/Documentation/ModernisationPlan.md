# Modernisation Plan: JSONSession, Octoid, ActionStatus

## Goal

Migrate the polling stack to a Swift 6 concurrency-safe architecture by removing session subclass inheritance as the primary extension mechanism, introducing typed processing context, and adopting actor-friendly APIs.

## Guiding Constraints

- Breaking changes are acceptable across all three packages.
- Preserve behaviour where possible (poll cadence, repeat/cancel decisions, API error handling).
- Move generic infrastructure to JSONSession; keep GitHub-specific payloads/endpoints in Octoid.

## Phase A: JSONSession API Foundation

1. Introduce typed processing context in `JSONSession`.
2. Update processor APIs to be async and context-based.
3. Remove runtime session-subclass casting from processor dispatch.
4. Keep session responsible for request scheduling and transport only.
5. Update JSONSession tests to validate the new context-based processing flow.

## Phase B: Octoid Composition Migration

1. Replace `Octoid.Session: JSONSession.Session` inheritance with composition/config wrappers.
2. Keep GitHub models/resources in Octoid (`Message`, `Events`, `WorkflowRuns`, resource resolvers).
3. Refactor `MessageProcessor` to use context callbacks instead of session subtype constraints.
4. Prefer reusable JSONSession generic processors where available.

## Phase C: ActionStatus Context Actor Migration

1. Replace `RepoPollingSession` mutable class state with a context actor (`repo`, `lastEvent`, controller hooks).
2. Update processors to act on the context actor rather than subclass internals.
3. Route UI/model updates through explicit `@MainActor` methods.
4. Preserve workflow/event polling semantics and cancellation behaviour.

## Phase D: Concurrency Hardening + Cleanup

1. Remove `@unchecked Sendable` where unnecessary.
2. Add explicit `Sendable` conformances for request/control/value types where valid.
3. Audit cancellation and task lifecycle for race-free behaviour.
4. Remove deprecated adapters/shims once downstream migration is complete.

## Validation Strategy

- Run `swift test` in each package after migration updates.
- Add focused tests for:
  - context-based dispatch and callback behavior,
  - repeat/cancel transitions,
  - unknown/unhandled response fallback,
  - cancellation/timeout safety.

## Expected API Impact

- Processor protocols become async and context-oriented.
- Polling entry points require a typed context.
- Session subclassing is no longer required for domain state and callback wiring.
