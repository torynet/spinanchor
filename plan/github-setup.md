# GitHub Setup Instructions

These instructions should be executed in order. They assume `gh` CLI is authenticated with access to the `torynet` GitHub organization.

## 1. Create GitHub Project

```bash
# Create the project
gh project create --owner torynet --title "SpinAnchor" --format TABLE

# Note the project number returned (e.g., 1). Use it in subsequent commands.
PROJECT_NUM=<number>
```

## 2. Create Custom Fields on the Project

```bash
# Phase field (Single Select)
gh project field-create $PROJECT_NUM --owner torynet --name "Phase" --data-type SINGLE_SELECT --single-select-options "Phase 1: Core MVP,Phase 2: Collaboration,Phase 3: Advanced"

# Component field (Single Select)
gh project field-create $PROJECT_NUM --owner torynet --name "Component" --data-type SINGLE_SELECT --single-select-options "Editor,Server,Database,Git,Search,Permissions,API,UI,Infrastructure,Documentation"

# Priority field (Single Select)
gh project field-create $PROJECT_NUM --owner torynet --name "Priority" --data-type SINGLE_SELECT --single-select-options "Critical,High,Medium,Low"

# Complexity field (Single Select)
gh project field-create $PROJECT_NUM --owner torynet --name "Complexity" --data-type SINGLE_SELECT --single-select-options "Small,Medium,Large,XL"
```

## 3. Create Milestone Labels

```bash
gh label create "phase:1-core" --repo torynet/spinanchor --description "Phase 1: Core MVP" --color "0E8A16"
gh label create "phase:2-collab" --repo torynet/spinanchor --description "Phase 2: Collaboration Features" --color "1D76DB"
gh label create "phase:3-advanced" --repo torynet/spinanchor --description "Phase 3: Advanced Features" --color "5319E7"

gh label create "component:editor" --repo torynet/spinanchor --color "FBCA04"
gh label create "component:server" --repo torynet/spinanchor --color "FBCA04"
gh label create "component:database" --repo torynet/spinanchor --color "FBCA04"
gh label create "component:git" --repo torynet/spinanchor --color "FBCA04"
gh label create "component:search" --repo torynet/spinanchor --color "FBCA04"
gh label create "component:permissions" --repo torynet/spinanchor --color "FBCA04"
gh label create "component:api" --repo torynet/spinanchor --color "FBCA04"
gh label create "component:ui" --repo torynet/spinanchor --color "FBCA04"
gh label create "component:infra" --repo torynet/spinanchor --color "FBCA04"

gh label create "type:feature" --repo torynet/spinanchor --color "A2EEEF"
gh label create "type:bug" --repo torynet/spinanchor --color "D73A4A"
gh label create "type:design" --repo torynet/spinanchor --color "D4C5F9"
gh label create "type:research" --repo torynet/spinanchor --color "C5DEF5"
gh label create "type:chore" --repo torynet/spinanchor --color "E4E669"

gh label create "decision-needed" --repo torynet/spinanchor --description "Requires a design decision before implementation" --color "FF6600"
gh label create "agent-ready" --repo torynet/spinanchor --description "Well-defined enough for a Claude agent to implement" --color "00CC00"
```

## 4. Create Phase 1 Issues

Each issue below corresponds to a work item in Phase 1. Issues should be created and added to the project with appropriate field values.

See `plan/phase1-issues.md` for the full list of issues with descriptions, acceptance criteria, and agent instructions.

```bash
# Example pattern for creating issues and adding to project:
ISSUE_URL=$(gh issue create --repo torynet/spinanchor \
  --title "Issue title" \
  --body "Issue body" \
  --label "phase:1-core,component:server,type:feature" \
  | tail -1)
gh project item-add $PROJECT_NUM --owner torynet --url "$ISSUE_URL"
```

Repeat for each issue defined in `plan/phase1-issues.md`.

## 5. Configure Repository Settings

```bash
# Protect main branch (require PR reviews)
# Note: branch protection may require GitHub API calls rather than gh CLI
# This can be configured manually or via the GitHub web UI

# Enable discussions (optional, for design conversations)
gh repo edit torynet/spinanchor --enable-discussions
```

## 6. Set Up GitHub Actions

CI pipeline should be created as part of Phase 1.1 (Project Scaffolding). The workflow file lives at `.github/workflows/ci.yml` and should:

- Run on push to main and on PRs
- Lint (ESLint)
- Type check (tsc --noEmit)
- Test (Vitest)
- Build (server + client)
