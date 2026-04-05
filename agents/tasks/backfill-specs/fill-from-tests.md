# Fill Acceptance from Tests

## Purpose

Populate the Acceptance section of spec files by reading test files and translating assertions into behavioral acceptance criteria.

## Preconditions

- Spec files with `> **TODO:**` Acceptance sections.
- Test roots identified in Phase 1 of the parent task.
- User has approved filling from tests (interactive mode) or this phase is in scope (headless mode).

## Steps

For each spec with a `> **TODO:**` Acceptance section:

1. **Find relevant test files** by path similarity (`src/foo/**` ↔ tests mentioning `foo`), import references, and naming conventions (`foo.test.ts`, `FooService.spec.ts`, etc.).

2. **Prioritize test types:** e2e / integration / contract first; unit tests sparingly — skip assertions about internal implementation details.

3. **Translate `describe` / `it` blocks** into behavioral AC bullets in the Acceptance section. Focus on observable outcomes, not implementation mechanics.

4. **Note source test file paths** after the ACs so the link is traceable:
   ```markdown
   ## Acceptance
   - Users can log in with email and password
   - Invalid credentials return a 401 with error message
   - Session expires after 30 minutes of inactivity

   *Source: `tests/auth/login.test.ts`, `tests/auth/session.test.ts`*
   ```

5. **Where tests are too thin** or unclear to produce honest ACs: leave the `> **TODO:**` in place and add a note:
   ```
   > **TODO:** Test coverage is sparse here — add integration tests before relying on this section.
   ```

## Inputs

- Spec files with empty Acceptance sections
- Test files in the repository

## Outputs

- Acceptance sections filled with behavioral AC bullets.
- Source test file paths noted for traceability.
