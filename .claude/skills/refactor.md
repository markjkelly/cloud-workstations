# /refactor — Safe refactoring workflow

## Trigger

User invokes `/refactor` with a target file, function, or module to refactor.

## Instructions

1. **Run existing tests first** — Execute the full test suite to establish a passing baseline:
   ```
   go test ./...
   ```
   If tests fail before refactoring, stop and report the failures
2. **Analyze the code** — Identify the specific improvements to make:
   - Unused code that can be removed
   - Functions that can be extracted or simplified
   - Poor naming that can be improved
   - Duplicated logic that can be consolidated
   - Complex conditionals that can be simplified
3. **Make refactoring changes** — Apply changes incrementally:
   - Change one thing at a time
   - Preserve all existing behavior (no functional changes)
   - Keep the public API stable unless explicitly asked to change it
4. **Run tests again** — After each change, run the test suite:
   ```
   go test ./...
   ```
   Fix any regressions immediately before continuing
5. **Verify no regressions** — Confirm:
   - All existing tests still pass
   - No new warnings or linting issues
   - The refactored code is genuinely simpler, not just different
6. **Commit the changes** — Stage and commit with a clear message explaining what was refactored and why
7. **Report back** — Summarize: what was changed, why it is better, and confirm all tests pass

## Project Context

- **Project:** Cloud Workstation
- **Owner:** Your Name (your-email@example.com)
