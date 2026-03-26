# /debug — Systematic debugging workflow

## Trigger

User invokes `/debug` with a bug description, error message, or unexpected behavior.

## Instructions

1. **Reproduce the issue** — Run the failing scenario to confirm the bug. Capture the exact error message, stack trace, or unexpected output
2. **Read the logs** — Check application logs, test output, and stderr for clues. Search for the error message in the codebase to find where it originates
3. **Isolate the root cause** — Trace the call stack from the error back to the source:
   - Add temporary logging or print statements if needed
   - Use `git bisect` if the bug is a regression and the failing commit is unclear
   - Check recent changes with `git log --oneline -20` for suspicious commits
   - Narrow down to the specific function, line, or condition that causes the failure
4. **Implement the fix** — Make the minimal change needed to resolve the root cause. Do not refactor surrounding code
5. **Write a regression test** — Add a test that fails without the fix and passes with it. This prevents the bug from recurring
6. **Verify the fix** — Run the full test suite to confirm:
   - The regression test passes
   - No existing tests are broken
   - The original reproduction case now works correctly
7. **Clean up** — Remove any temporary logging or debug statements added in step 3
8. **Report back** — Summarize: what the bug was, what caused it, what the fix was, and what test was added

## Project Context

- **Project:** Cloud Workstation
- **Owner:** Your Name (your-email@example.com)
