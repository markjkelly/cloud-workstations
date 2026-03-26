# /review — Code review checklist

## Trigger

User invokes `/review` with a file, diff, branch, or PR to review.

## Instructions

1. **Read the changes** — Read the diff or changed files. Understand the intent of the change and what problem it solves
2. **Check security** (OWASP Top 10):
   - Injection vulnerabilities (SQL, command, XSS)
   - Broken authentication or authorization
   - Sensitive data exposure (hardcoded secrets, API keys, credentials)
   - Insecure deserialization or input validation
3. **Check performance:**
   - Unnecessary allocations or copies
   - N+1 queries or unbounded loops
   - Missing pagination or rate limiting
   - Resource leaks (unclosed files, connections, channels)
4. **Check correctness:**
   - Logic errors, off-by-one, nil pointer dereferences
   - Missing error handling (unchecked errors, swallowed errors)
   - Race conditions in concurrent code
   - Incomplete state transitions
5. **Check error handling:**
   - Errors are propagated, not silently ignored
   - Error messages are actionable and include context
   - Cleanup happens in defer blocks where appropriate
6. **Check style and maintainability:**
   - Code follows project conventions
   - Names are clear and descriptive
   - Functions are focused (single responsibility)
   - No dead code or unnecessary complexity
7. **Output findings** — Provide a structured review with severity levels:
   - **Critical** — Must fix before merge (security issues, data loss, crashes)
   - **Warning** — Should fix (performance, correctness concerns)
   - **Info** — Suggestions (style, readability improvements)

## Project Context

- **Project:** Cloud Workstation
- **Owner:** Your Name (your-email@example.com)
