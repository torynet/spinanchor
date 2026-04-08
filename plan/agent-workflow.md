# Agent Workflow Guide

How to use Claude agents to implement spinanchor.

## Project Management Model

- **Tory** (project owner): Makes design decisions, reviews PRs, resolves open questions in `plan/open-decisions.md`.
- **Claude agents**: Implement features defined in GitHub issues. Each issue has agent instructions.

## Before Starting Any Implementation

1. **Check `plan/open-decisions.md`** for unresolved decisions that affect the issue. If a required decision is unresolved, stop and flag it — do not guess.
2. **Read the issue description and acceptance criteria** in full. Every checkbox must be satisfied.
3. **Read the agent instructions** section of the issue. These contain implementation-specific guidance.
4. **Check for dependencies.** If the issue depends on another issue that isn't completed, stop.
5. **Read relevant plan files** (`plan/architecture.md`, `plan/technology-stack.md`, `plan/phases.md`) for context.

## Implementation Process

For each issue:

1. **Create a feature branch** from `main`: `git checkout -b feature/{issue-number}-{short-description}`
2. **Implement** according to the acceptance criteria and agent instructions.
3. **Write tests.** Every feature should have unit tests. Integration tests where noted in the issue.
4. **Ensure CI passes**: lint, type-check, test, build must all succeed.
5. **Create a PR** targeting `main` with a clear description referencing the issue number.
6. **PR description** should include:
   - What was implemented
   - Any decisions made during implementation (document these in code comments or plan files)
   - Any deviations from the plan and why
   - How to test

## Code Standards

- **TypeScript**: Strict mode. No `any` types except where truly unavoidable (and document why).
- **Tests**: Vitest. Test files co-located with source (`*.test.ts`).
- **Formatting**: Prettier with project defaults. Run before committing.
- **Linting**: ESLint with project config. Zero warnings in CI.
- **Imports**: Use path aliases (`@server/...`, `@client/...`) rather than deep relative paths.
- **Error handling**: No silent failures. Errors should be typed and handled explicitly.
- **Logging**: Use a structured logger (pino or similar). No `console.log` in production code.

## Commit Convention

Use conventional commits:

```
feat(editor): add Mermaid diagram rendering
fix(git): handle empty frontmatter on publish
chore(infra): update Docker base image to node:22.4
test(search): add FTS5 ranking integration tests
docs(plan): resolve D-008 database schema decision
```

## When You're Stuck

- If an issue is ambiguous, check the plan files for context.
- If a design decision is needed that isn't covered, add it to `plan/open-decisions.md` with a recommended approach and flag it for Tory's review.
- If a dependency (npm package, API) doesn't work as expected, document the issue and pivot if a reasonable alternative exists. Don't spend hours debugging a library — switch to the alternative and note why.
- If acceptance criteria seem wrong or contradictory, flag it in the PR description.

## File Organization

```
spinanchor/
├── .github/
│   └── workflows/
│       └── ci.yml
├── packages/
│   ├── server/
│   │   ├── src/
│   │   │   ├── db/           # Database layer, migrations, queries
│   │   │   ├── git/          # isomorphic-git operations
│   │   │   ├── api/          # REST API routes
│   │   │   ├── auth/         # OAuth2/OIDC
│   │   │   ├── collab/       # Yjs/WebSocket collaboration server
│   │   │   ├── search/       # FTS5 search
│   │   │   └── index.ts      # Server entry point
│   │   ├── tsconfig.json
│   │   └── package.json
│   └── client/
│       ├── src/
│       │   ├── editor/       # Milkdown editor setup and plugins
│       │   ├── pages/        # Page components / views
│       │   ├── components/   # Shared UI components
│       │   └── main.ts       # Client entry point
│       ├── vite.config.ts
│       ├── tsconfig.json
│       └── package.json
├── plan/                     # Design documents and decisions
├── LICENSE.md
├── README.md
├── pnpm-workspace.yaml
├── tsconfig.base.json
└── package.json
```

## Definition of Done

An issue is done when:

1. All acceptance criteria checkboxes are satisfied
2. Tests pass (unit + integration where specified)
3. CI pipeline passes (lint, type-check, test, build)
4. PR is created with clear description
5. No new unresolved warnings or errors introduced
6. Any new decisions or deviations are documented
