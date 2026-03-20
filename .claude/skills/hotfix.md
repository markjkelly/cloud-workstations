# /hotfix — Emergency fix workflow

## Trigger

User invokes `/hotfix` with a critical bug description that needs an immediate fix.

## Instructions

1. **Create a hotfix branch** from main:
   ```
   git checkout main && git pull
   git checkout -b hotfix/<description>
   ```
2. **Implement the minimal fix** — Make the smallest change possible that resolves the issue. No feature work, no refactoring, no cleanup — only the fix
3. **Write a test** — Add a test that reproduces the original bug and verifies the fix
4. **Run all tests** — Ensure nothing else is broken:
   ```
   go test ./...
   ```
5. **Commit the fix:**
   ```
   git -c user.name="Ameer Abbas" -c user.email="ameer00@gmail.com" add -A
   git -c user.name="Ameer Abbas" -c user.email="ameer00@gmail.com" commit -m "hotfix: <description>"
   ```
6. **Merge to main:**
   ```
   git checkout main
   git merge hotfix/<description>
   ```
7. **Tag a patch release** — Bump the patch version:
   ```
   git -c user.name="Ameer Abbas" -c user.email="ameer00@gmail.com" tag -a vX.Y.Z -m "Hotfix: <description>"
   ```
8. **Push everything:**
   ```
   git push origin main && git push origin vX.Y.Z
   ```
9. **Report back** — Confirm: what was fixed, the hotfix branch name, the new tag, and that all tests pass

## Project Context

- **Project:** Cloud Workstation
- **Owner:** Ameer Abbas (ameer00@gmail.com)
