# /spec — Create a new product spec

## Trigger

User invokes `/spec` with a feature title or description.

## Instructions

1. **Determine the next F-NNNN ID** — Read `docs/BACKLOG.md` and scan for the highest existing `F-NNNN` ID. The next spec gets the next sequential number (e.g., if the highest is F-0041, the next is F-0042)
2. **Create the spec file** — Copy `docs/specs/TEMPLATE.md` to `docs/specs/F-NNNN-short-slug.md` where:
   - `NNNN` is the next sequential ID (zero-padded to 4 digits)
   - `short-slug` is a kebab-case version of the feature title (e.g., "Add dark mode" becomes `add-dark-mode`)
3. **Fill in the spec** — Update the copied template with:
   - **Title:** The feature title from the user's input
   - **Type:** Feature, Bug, or Enhancement (infer from the description, default to Feature)
   - **Priority:** P1 unless the user specifies otherwise
   - **Status:** Draft
   - **Requested by:** PO
   - **Date:** Today's date
   - **Problem:** Describe the problem or need based on the user's input
   - **Requirements:** Numbered list of specific, testable requirements
   - **Acceptance Criteria:** Checkboxes with measurable criteria
   - **Out of Scope:** Note what is explicitly excluded
   - **Dependencies:** List any dependencies on other features
4. **Report back** — Show the user the path to the new spec file and a summary of what was created

## Project Context

- **Project:** Cloud Workstation
- **Owner:** Ameer Abbas (ameer00@gmail.com)
- **Specs directory:** `docs/specs/`
- **Spec template:** `docs/specs/TEMPLATE.md`
- **Backlog:** `docs/BACKLOG.md`
