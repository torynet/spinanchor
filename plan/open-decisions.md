# Open Decisions

Decisions that need to be made before or during implementation. Each entry describes the decision, the options considered, and any recommendation.

## Pre-Implementation

### D-001: Project Name

**Status**: Resolved
**Decision**: spinanchor

### D-002: Public or Private Repo

**Status**: Resolved
**Decision**: Public

### D-003: Node.js Minimum Version

**Status**: Recommended Node 22+
**Blocker for**: package.json engines field, CI configuration

Node 22+ is recommended because it includes built-in `node:sqlite`. If we need to support older Node versions, we'd need `better-sqlite3` (native dependency, compilation required). Recommend requiring Node 22+ and documenting this clearly.

**Decision needed**: Confirm Node 22+ as minimum.

### D-004: Monorepo or Separate Packages

**Status**: Unresolved
**Blocker for**: Repo structure, build tooling

The system has at least two distinct deliverables:
1. The server (Node.js, handles CRDT sessions, git, database, API)
2. The browser client (TypeScript, Milkdown editor, Yjs client)

Options:
- **Monorepo with workspaces**: Single repo, `packages/server` and `packages/client`. Managed via npm workspaces, pnpm, or turborepo. Simplest for development, atomic commits across server+client.
- **Single package**: Server serves the built client as static assets. Simpler structure but mixes concerns.
- **Separate repos**: Maximum separation but complicates coordinated development.

**Recommendation**: Monorepo with workspaces. The server and client are tightly coupled (shared types, coordinated releases) and should live together.

### D-005: Package Manager

**Status**: Unresolved
**Blocker for**: Repo setup, CI, contributor docs

Options:
- **npm**: Ships with Node.js. No extra install. Workspace support is adequate.
- **pnpm**: Faster, stricter dependency resolution, better disk usage. Requires separate install.
- **yarn**: Less momentum in 2025+.

**Recommendation**: pnpm. It's the standard for TypeScript monorepos in 2025 and its strictness catches dependency issues early.

### D-006: TypeScript Build Tooling

**Status**: Unresolved
**Blocker for**: Project setup

Server-side and client-side have different build needs:
- Server: TypeScript → JavaScript. Options: tsc, tsx, tsup, esbuild.
- Client: TypeScript + bundling for browser. Options: Vite, esbuild, webpack.

**Recommendation**: Vite for the client (standard for frontend in 2025, fast, good DX). tsup or tsx for the server (fast TypeScript execution without full bundling).

### D-007: Testing Framework

**Status**: Unresolved
**Blocker for**: Phase 1 implementation

Options:
- **Vitest**: Fast, Vite-native, good TypeScript support. Works for both server and client.
- **Jest**: Mature, widely known, but slower and requires more config for TypeScript/ESM.
- **Node.js built-in test runner**: Minimal, no dependencies, but less feature-rich.

**Recommendation**: Vitest. Fast, single framework for server + client, native ESM/TypeScript support.

## Design Decisions (During Implementation)

### D-008: Database Schema Design

**Status**: Needs design
**Blocker for**: Phase 1 implementation

The SQLite database schema needs to be designed to support:
- Document drafts and CRDT state
- Search index (FTS5 virtual table)
- Backlinks graph
- Tags index
- User accounts and sessions
- Space and page permissions
- Comments (Phase 2)
- CRDT operation logs (Phase 2)

This should be designed upfront and documented in `plan/database-schema.md` before implementation begins.

### D-009: URL Scheme

**Status**: Needs design
**Blocker for**: Phase 1 implementation

How are documents addressed in the web UI?
- `/{space}/{slug}` — simple, clean
- `/{space}/{path/to/slug}` — supports sub-folders within spaces
- `/wiki/{space}/{slug}` — namespaced under `/wiki` to leave room for `/api`, `/settings`, etc.

**Recommendation**: `/wiki/{space}/{slug}` for page views, `/api/v1/...` for REST API, `/settings/...` for admin UI.

### D-010: Frontmatter Schema

**Status**: Needs design
**Blocker for**: Phase 1 implementation

Define the standard YAML frontmatter fields:
- `title` (required)
- `tags` (array, optional)
- `aliases` (array, optional)
- `author` (string, set on creation)
- `created` (ISO date, set on creation)
- Other fields TBD

Should be documented in `plan/frontmatter-schema.md`.

### D-011: Git Repo Layout

**Status**: Needs design
**Blocker for**: Phase 1 implementation

Proposed:
```
{space-slug}/
  {document-slug}.md
  _templates/
    {template-slug}.md
```

Questions:
- Are sub-folders within a space allowed? If so, do they affect the URL scheme?
- Where do global templates live? Root `_templates/` directory?
- Are there any reserved directory names besides `_templates`?

### D-012: OAuth2/OIDC Provider Requirements

**Status**: Needs design
**Blocker for**: Phase 1 implementation

What OIDC providers should be supported out of the box?
- Google
- GitHub
- Azure AD / Entra ID
- Generic OIDC (any provider)

Should the system support multiple simultaneous providers?

**Recommendation**: Support generic OIDC configuration (works with any provider) plus convenience presets for Google, GitHub, and Azure AD. Multiple simultaneous providers should be supported from the start.

### D-013: Editor Raw Markdown Toggle

**Status**: Needs design
**Blocker for**: Phase 1 implementation

Should users be able to toggle between rich-text editing (Milkdown WYSIWYG) and raw markdown source? This is a common feature in markdown editors (HedgeDoc, Obsidian).

Implications: If users can edit raw markdown, the CRDT needs to operate on plain text rather than the ProseMirror document model. This may require two CRDT modes or a translation layer.

**Recommendation**: Rich-text only in v1. Raw markdown toggle as a v2 feature. The complexity of dual-mode editing is significant and the target user (non-developer wiki contributor) is better served by WYSIWYG.
