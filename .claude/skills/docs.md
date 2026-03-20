# /docs — Generate or update documentation

## Trigger

User invokes `/docs` with a target module, API, feature, or file to document.

## Instructions

1. **Read the target code** — Understand the public API, exported types, functions, and their behavior. Note any configuration options or environment variables
2. **Generate documentation** in markdown format:
   - **Overview** — Brief description of what the module/feature does
   - **Usage** — Code examples showing common usage patterns
   - **API Reference** — Document each exported function/type with:
     - Signature
     - Parameters and return values
     - Example usage
   - **Configuration** — Document any config options, environment variables, or flags
3. **Update README if relevant** — If the documented module is a top-level feature, add or update its section in the project README
4. **Add inline comments** — For complex logic that is not self-documenting, add brief comments explaining the "why" (not the "what")
5. **Verify accuracy** — Ensure all documented APIs match the actual code. Run examples if possible to confirm they work
6. **Report back** — Summarize what was documented and where the documentation was written

## Project Context

- **Project:** Cloud Workstation
- **Owner:** Ameer Abbas (ameer00@gmail.com)
