# Development Pipeline — Cloud Workstation

> How features, bugs, and enhancements flow through the agent team.

```mermaid
flowchart TD
    PO(["PO (Product Owner)"])
    PM["PM"]
    TPM["TPM"]
    SWE1["SWE-1: General Engineer 1"]
    SWE2["SWE-2: General Engineer 2"]
    SWE3["SWE-3: General Engineer 3"]
    SWETEST["SWE-Test"]
    SWEQA["SWE-QA"]
    PLAT["Platform Engineer"]
    REV["Reviewer"]
    BACKLOG[("docs/BACKLOG.md")]
    PROGRESS[("docs/PROGRESS.md")]
    RELEASENOTES[("docs/RELEASENOTES.md")]
    TAG{{"git tag vX.Y.Z"}}

    %% ── Downward flow (request → execution) ──
    PO -->|"feedback / bugs / features"| PM
    PM -->|"spec + requirements"| TPM
    TPM -->|"assign work"| SWE1
    TPM -->|"assign work"| SWE2
    TPM -->|"assign work"| SWE3
    SWE1 -->|"hand off"| SWETEST
    SWE2 -->|"hand off"| SWETEST
    SWE3 -->|"hand off"| SWETEST
    SWE1 -->|"hand off"| SWEQA
    SWE2 -->|"hand off"| SWEQA
    SWE3 -->|"hand off"| SWEQA
    SWE1 -->|"code review"| REV
    SWE2 -->|"code review"| REV
    SWE3 -->|"code review"| REV

    %% ── Upward flow (results → reporting) ──
    SWETEST -.->|"test results"| SWE1
    SWETEST -.->|"test results"| SWE2
    SWETEST -.->|"test results"| SWE3
    SWEQA -.->|"QA results"| SWE1
    SWEQA -.->|"QA results"| SWE2
    SWEQA -.->|"QA results"| SWE3
    REV -.->|"review feedback"| SWE1
    REV -.->|"review feedback"| SWE2
    REV -.->|"review feedback"| SWE3
    SWE1 -->|"work complete"| TPM
    SWE2 -->|"work complete"| TPM
    SWE3 -->|"work complete"| TPM
    TPM -->|"milestone complete"| PM
    PM -->|"summary report"| PO

    %% ── Side effects (docs & tagging) ──
    PM -.->|"create / update items"| BACKLOG
    SWE1 -.->|"update"| BACKLOG
    SWE2 -.->|"update"| BACKLOG
    SWE3 -.->|"update"| BACKLOG
    TPM -.->|"session log"| PROGRESS
    PM -.->|"version entry"| RELEASENOTES
    PM -.->|"tag release"| TAG
    PLAT -.->|"infra support"| SWE1
    PLAT -.->|"infra support"| SWE2
    PLAT -.->|"infra support"| SWE3

    %% ── Link colors ──
    linkStyle 0,1,2,3,4,5,6,7,8,9,10,11,12,13 stroke:#2ea043,stroke-width:2px
    linkStyle 14,15,16,17,18,19,20,21,22,23,24,25,26,27 stroke:#58a6ff,stroke-width:2px
```

## Legend

- **Green arrows** (`→`) — Downward flow: request → execution
- **Blue arrows** (`⇢`) — Upward flow: results → reporting
- **Gray dashed** — Side effects (docs updates, tagging, infra support)

## Pipeline Steps

1. **PO** provides feedback, bug reports, or feature requests to the **PM**
2. **PM** creates a product spec (`docs/specs/F-NNNN-slug.md`) and translates feedback into detailed requirements
3. **PM** works with **TPM** to create and prioritize items in docs/BACKLOG.md
4. **TPM** assigns individual work items to **SWE** agents
5. **SWE** agents implement on feature branches
6. **SWE-Test** runs automated tests to verify implementation
7. **SWE-QA** performs end-to-end quality assurance
8. **Reviewer** conducts code review for quality, security, and performance
9. **Platform Engineer** provides infrastructure and deployment support
10. **SWE** agents update docs/BACKLOG.md and inform **TPM** when work is complete
11. **TPM** updates docs/PROGRESS.md with session details (what was done, decisions, next steps)
12. **TPM** waits for all milestone items to complete, then reports to **PM**
13. **PM** updates docs/RELEASENOTES.md with the new version entry (Added, Changed, Fixed)
14. **PM** creates a summary of completed work and reports back to the **PO**
15. **Tag release** — after PO approval, create annotated git tag (`git tag -a vX.Y.Z`) and push
