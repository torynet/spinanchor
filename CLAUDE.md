# CLAUDE.md

## Project Overview

spinanchor is a real-time collaborative markdown wiki with git-backed storage. See `plan/architecture.md` for the full architecture and `plan/feasibility-study.md` for the research backing.

## Key Files

- `plan/architecture.md` — System architecture and design decisions
- `plan/technology-stack.md` — All dependencies and alternatives
- `plan/phases.md` — Project phases and feature breakdown
- `plan/phase1-issues.md` — Detailed issue definitions with agent instructions
- `plan/open-decisions.md` — Unresolved design decisions (CHECK BEFORE IMPLEMENTING)
- `plan/agent-workflow.md` — How to implement features as an agent
- `plan/feasibility-study.md` — Full feasibility research
- `plan/concept-research.md` — Original concep research

## Rules

- **Check `plan/open-decisions.md` before implementing anything.** If a required decision is unresolved, stop and flag it.
- **All code is TypeScript.** Strict mode. No `any` types without documented justification.
- **No native dependencies.** Everything must be pure JavaScript/TypeScript. Use `node:sqlite` (not better-sqlite3), `isomorphic-git` (not libgit2).
- **Node 22+ required.** We use built-in `node:sqlite`.
- **Tests are mandatory.** Every feature needs tests. Use Vitest.
- **Conventional commits.** `issue-type(scope):` e.g. `123-feat(scope):`, `124-fix(scope):`, `125-chore(scope):`, etc.
- **BlueOak Model License 1.0.0.** All contributions are under this license.
- **No session links in commits.** Do not append Claude Code session URLs to commit messages or PR descriptions.
- **PR reviewer.** Always request review from `torynet` on pull requests.

## Tech Stack Quick Reference

| What | Technology |
|------|-----------|
| Runtime | Node.js 22+ |
| Language | TypeScript (strict) |
| Package manager | pnpm |
| Editor | Milkdown (ProseMirror + Remark) |
| CRDT | Yjs + y-websocket |
| Database | node:sqlite with FTS5 |
| Git | isomorphic-git |
| Auth | OAuth2/OIDC |
| Test framework | Vitest |
| Client build | Vite |
| Server build | tsup or tsx |
| Linting | ESLint + Prettier |
