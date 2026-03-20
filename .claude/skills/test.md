# /test — Write tests for a module or function

## Trigger

User invokes `/test` with a target file, function, or module to test.

## Instructions

1. **Read the target code** — Understand the function signatures, input types, return values, and side effects. Note any dependencies or external calls
2. **Identify edge cases** — Consider:
   - Normal/happy path inputs
   - Boundary values (zero, empty, nil, max)
   - Error conditions (invalid input, missing data, permission errors)
   - Concurrency concerns (if applicable)
3. **Generate table-driven tests** — Use the table-driven test pattern:
   - Define a slice of test cases with name, inputs, and expected outputs
   - Use `t.Run(tc.name, ...)` for subtests
   - Include both positive and negative test cases
4. **Follow testing best practices:**
   - Use `t.TempDir()` for any filesystem operations
   - No external dependencies — use only the standard library
   - Write meaningful assertion messages that explain what was expected vs what was received
   - Use `t.Helper()` in helper functions
   - Use `t.Parallel()` where safe
5. **Run the tests** — Execute the test suite and verify all tests pass:
   ```
   go test ./... -v
   ```
6. **Report coverage** — Check coverage for the target package:
   ```
   go test ./path/to/package -cover
   ```
7. **Report back** — Summarize: how many tests were added, what cases are covered, and the coverage percentage

## Project Context

- **Project:** Cloud Workstation
- **Owner:** Ameer Abbas (ameer00@gmail.com)
