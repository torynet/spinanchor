# Phase 1 Issues

Each section below defines a GitHub issue. Create these issues in the `torynet/spinanchor` repo and add them to the spinanchor project with Phase set to "Phase 1: Core MVP".

Issues are ordered by dependency. Earlier issues should be completed before later ones where noted.

---

## Issue 1: Project Scaffolding

**Labels**: `phase:1-core`, `component:infra`, `type:chore`
**Priority**: Critical
**Complexity**: Medium
**Depends on**: Nothing (first issue)

### Description

Initialize the monorepo structure with all build tooling, linting, testing, and CI.

### Acceptance Criteria

- [ ] pnpm workspace with `packages/server` and `packages/client`
- [ ] TypeScript configuration for both packages (strict mode)
- [ ] Server: tsup or tsx for TypeScript execution
- [ ] Client: Vite for build and dev server
- [ ] Vitest configured for both packages with example passing tests
- [ ] ESLint + Prettier with shared config
- [ ] `Dockerfile` and `docker-compose.yml` for development
- [ ] `.github/workflows/ci.yml`: lint, type-check, test, build on push/PR
- [ ] `package.json` `engines` field requiring Node 22+
- [ ] `.gitignore` covering node_modules, dist, .env, *.db

### Agent Instructions

Before implementing, review:
- `plan/open-decisions.md` for D-004 (monorepo), D-005 (package manager), D-006 (build tooling), D-007 (testing)
- If any of these decisions are still unresolved, flag them and stop. Do not guess.

Use pnpm workspaces. Structure:
```
packages/
  server/
    src/
    tsconfig.json
    package.json
  client/
    src/
    tsconfig.json
    package.json
    vite.config.ts
pnpm-workspace.yaml
tsconfig.base.json
package.json
```

---

## Issue 2: SQLite Database Layer

**Labels**: `phase:1-core`, `component:database`, `type:feature`
**Priority**: Critical
**Complexity**: Large
**Depends on**: Issue 1

### Description

Implement the SQLite database layer using Node 22+ built-in `node:sqlite`. Design and create the schema for all Phase 1 tables. Implement a migration system.

### Acceptance Criteria

- [ ] Database initialization on first run (create tables)
- [ ] Migration system (versioned SQL migrations, applied on startup)
- [ ] Tables: documents, spaces, tags, document_tags, users, sessions, permissions, backlinks
- [ ] FTS5 virtual table for full-text search
- [ ] Database access layer with typed queries (no raw SQL in business logic)
- [ ] Database rebuilds search index and backlinks from markdown files on startup
- [ ] Unit tests for all database operations
- [ ] Schema documented in `plan/database-schema.md`

### Agent Instructions

Before implementing, check if `plan/database-schema.md` exists. If not, design the schema first and write it to that file for review before implementing.

Use `node:sqlite` (built into Node 22+). Do NOT use better-sqlite3 or node-sqlite3.

The database must support being rebuilt from the git repo's markdown files. All published content, search index, backlinks, and tags should be derivable from the `.md` files. Only drafts, CRDT state, comments, permissions, and user data are database-exclusive.

---

## Issue 3: Core Editor Integration

**Labels**: `phase:1-core`, `component:editor`, `type:feature`
**Priority**: Critical
**Complexity**: XL
**Depends on**: Issue 1

### Description

Integrate Milkdown editor with Yjs for real-time collaborative editing. Set up the WebSocket server for CRDT sync.

### Acceptance Criteria

- [ ] Milkdown editor renders in the browser
- [ ] GFM support: tables, task lists, footnotes, strikethrough
- [ ] Mermaid diagram rendering (live preview or rendered on blur)
- [ ] Callout/admonition support (Obsidian-compatible `> [!note]` syntax)
- [ ] Math support (KaTeX, `$inline$` and `$$block$$`)
- [ ] Wiki-link syntax: `[[Page Name]]` renders as clickable link
- [ ] Yjs integration: multiple browser tabs can edit the same document simultaneously
- [ ] y-websocket server running alongside the HTTP server
- [ ] Cursor awareness: see other users' cursors and selections
- [ ] Editor serializes to clean markdown (verify round-trip: markdown → editor → markdown)
- [ ] Unit/integration tests for editor serialization

### Agent Instructions

Start with a minimal Milkdown setup and add extensions incrementally. Test markdown round-tripping for each extension — the serialized output must be valid, portable markdown.

For wiki-links, implement a custom Remark plugin that parses `[[Page Name]]` and `[[Page Name|Display Text]]` syntax. The rendered output should be a clickable link that navigates to the referenced page.

For Mermaid, use `remark-mermaid` or render fenced code blocks with class `mermaid` client-side using the Mermaid JS library.

For Yjs integration, use Milkdown's official collab plugin if available. If not, integrate y-prosemirror directly with Milkdown's underlying ProseMirror instance.

---

## Issue 4: Git Persistence Layer

**Labels**: `phase:1-core`, `component:git`, `type:feature`
**Priority**: Critical
**Complexity**: Large
**Depends on**: Issue 2

### Description

Implement git operations using isomorphic-git. Handle publish (commit), startup (seed from git), and external edit detection.

### Acceptance Criteria

- [ ] Initialize git repo on first run if none exists
- [ ] Publish action: serialize document to `.md` with YAML frontmatter, stage, commit
- [ ] Commit message includes author name and meaningful description
- [ ] Co-author trailers for multi-contributor drafts
- [ ] Per-file mutex prevents simultaneous publishes of the same document
- [ ] On startup: read all `.md` files from git repo, seed database (published content, tags, search index, backlinks)
- [ ] External edit detection: poll for new commits on main at configurable interval
- [ ] When external changes detected: update database for affected files
- [ ] If a file with an active CRDT session is changed externally: notify connected editors
- [ ] Push to remote (optional, configurable)
- [ ] Integration tests covering publish, startup seed, and external edit detection

### Agent Instructions

Use `isomorphic-git` — do NOT use git CLI or libgit2. isomorphic-git is pure JavaScript with no native dependencies.

For YAML frontmatter, use the `gray-matter` npm package or a similar parser.

The publish flow:
1. Serialize Milkdown document to markdown string
2. Prepend YAML frontmatter (title, tags, aliases, author, dates)
3. Write to `{space}/{slug}.md` in the git working tree
4. `git add` the file
5. `git commit` with author attribution
6. Optionally `git push` to remote

For external edit detection, implement a polling loop (configurable interval, default 30 seconds) that runs `git fetch` and compares local HEAD to remote HEAD. If they differ, identify changed files and update the database.

---

## Issue 5: Spaces, Tags, and Navigation UI

**Labels**: `phase:1-core`, `component:ui`, `type:feature`
**Priority**: High
**Complexity**: Large
**Depends on**: Issues 2, 3, 4

### Description

Build the navigation UI: spaces, tag browsing, document lists, backlinks panel.

### Acceptance Criteria

- [ ] Space list view (sidebar or top-level navigation)
- [ ] Create/configure space (admin only)
- [ ] Document list within a space (sorted by title, last modified)
- [ ] Tag browser: list all tags, click to filter documents by tag
- [ ] Tag filtering works across spaces
- [ ] Nested tag display (e.g., `architecture/decisions` shows hierarchy)
- [ ] Backlinks panel on each document view ("What links here")
- [ ] Recent documents view
- [ ] Breadcrumb navigation showing space and document
- [ ] Responsive layout (usable on tablet, functional on mobile)

### Agent Instructions

For the frontend framework, use React unless a decision has been made otherwise. Milkdown has React integration support.

Navigation state (current space, tag filters) should be reflected in the URL for bookmarkability and sharing.

Tag browser should show tag counts (number of documents per tag). Nested tags should be collapsible.

---

## Issue 6: Full-Text Search

**Labels**: `phase:1-core`, `component:search`, `type:feature`
**Priority**: High
**Complexity**: Medium
**Depends on**: Issue 2

### Description

Implement search UI and API backed by SQLite FTS5.

### Acceptance Criteria

- [ ] Search bar accessible from all pages (global search)
- [ ] Full-text search over document content (rendered text, not raw markdown syntax)
- [ ] Search results ranked by BM25 relevance
- [ ] Results show title, space, snippet with highlighted matches
- [ ] Filter search by space, tag
- [ ] Search index updated on each publish
- [ ] Search index rebuilt from git on startup
- [ ] REST API endpoint: `GET /api/v1/search?q=...&space=...&tag=...`
- [ ] Search handles partial words / prefix matching
- [ ] Unit tests for search indexing and querying

### Agent Instructions

Index the rendered text content of each document (strip markdown syntax). Also index frontmatter fields (title, tags) as separate columns for filtered queries.

Use SQLite FTS5 with the `unicode61` tokenizer for broad language support. Configure BM25 ranking.

---

## Issue 7: Permissions and Authentication

**Labels**: `phase:1-core`, `component:permissions`, `type:feature`
**Priority**: High
**Complexity**: Large
**Depends on**: Issue 2

### Description

Implement OAuth2/OIDC authentication and role-based permissions.

### Acceptance Criteria

- [ ] OAuth2/OIDC login flow (redirect to provider, callback handling, session creation)
- [ ] Generic OIDC configuration (works with any compliant provider)
- [ ] Convenience presets for Google, GitHub, Azure AD
- [ ] Session management (secure cookies or tokens)
- [ ] Role-based access per space: Viewer, Editor, Admin
- [ ] Page-level restrictions (subtractive: restrict view or edit to specific users/groups)
- [ ] Permission checks on all API endpoints and page loads
- [ ] Admin UI: manage spaces, assign roles, view users
- [ ] First user to log in becomes system admin (bootstrap)
- [ ] Integration tests for permission enforcement

### Agent Instructions

Use a well-established OIDC client library for Node.js (e.g., `openid-client` or `arctic`). Do not implement the OAuth2 flow from scratch.

Permissions are checked server-side on every request. The client receives only the data the user is authorized to see.

For the admin bootstrap: if no users exist in the database, the first user to successfully authenticate via OIDC is granted system admin privileges.

---

## Issue 8: REST API

**Labels**: `phase:1-core`, `component:api`, `type:feature`
**Priority**: High
**Complexity**: Medium
**Depends on**: Issues 2, 4, 6, 7

### Description

Implement the REST API for all Phase 1 operations.

### Acceptance Criteria

- [ ] `GET /api/v1/pages` — list pages (filterable by space, tag)
- [ ] `GET /api/v1/pages/:space/:slug` — get page content and metadata
- [ ] `POST /api/v1/pages` — create page (returns draft)
- [ ] `PUT /api/v1/pages/:space/:slug` — update draft
- [ ] `POST /api/v1/pages/:space/:slug/publish` — publish (commit to git)
- [ ] `DELETE /api/v1/pages/:space/:slug` — delete page
- [ ] `POST /api/v1/pages/:space/:slug/rename` — rename (exclusive operation)
- [ ] `GET /api/v1/spaces` — list spaces
- [ ] `POST /api/v1/spaces` — create space
- [ ] `GET /api/v1/tags` — list all tags with counts
- [ ] `GET /api/v1/search?q=...` — full-text search
- [ ] `GET /api/v1/pages/:space/:slug/backlinks` — get backlinks
- [ ] `GET /api/v1/pages/:space/:slug/history` — get git log for a page
- [ ] Authentication required on all endpoints (except health check)
- [ ] Permission enforcement on all endpoints
- [ ] OpenAPI 3.x spec generated or hand-authored
- [ ] Integration tests for all endpoints

### Agent Instructions

Use Express or Fastify for the HTTP server. Choose based on current best practices — either is fine.

All endpoints return JSON. Use consistent error response format: `{ error: { code: "...", message: "..." } }`.

Pagination: use cursor-based pagination for list endpoints.

---

## Issue 9: External Edit Detection and Notification

**Labels**: `phase:1-core`, `component:git`, `type:feature`
**Priority**: Medium
**Complexity**: Medium
**Depends on**: Issues 3, 4

### Description

Detect when external commits land on main and notify active editors.

### Acceptance Criteria

- [ ] Polling loop checks for new commits at configurable interval (default 30s)
- [ ] When new commits detected: identify which files changed
- [ ] For changed files with no active CRDT session: update database silently
- [ ] For changed files with active CRDT sessions: send WebSocket notification to connected editors
- [ ] Notification UI: banner or modal informing user "External changes detected for this document"
- [ ] Stash option: user can snapshot their current draft before external changes are applied
- [ ] Default behavior: accept external changes (main is canonical)
- [ ] Stash stored in database, retrievable by user
- [ ] Integration tests for detection and notification flow

### Agent Instructions

This builds on the git polling implemented in Issue 4. The key addition is the WebSocket notification path — when external changes affect a file that has active editors, send a message via the existing y-websocket connection (or a separate control channel).

The stash is a simple snapshot of the current CRDT state stored as a blob in the database, tagged with user ID, document ID, and timestamp.

---

## Issue 10: Docker Production Deployment

**Labels**: `phase:1-core`, `component:infra`, `type:chore`
**Priority**: Medium
**Complexity**: Medium
**Depends on**: All other Phase 1 issues

### Description

Create production-ready Docker configuration.

### Acceptance Criteria

- [ ] Multi-stage Dockerfile (build + runtime)
- [ ] Runtime image based on `node:22-slim` or `node:22-alpine`
- [ ] `docker-compose.yml` for production: app + optional reverse proxy (Caddy)
- [ ] Environment variable configuration for: OIDC provider, git remote, LFS endpoint (future)
- [ ] Mounted volumes for: SQLite database, git repository
- [ ] Health check endpoint (`GET /health`)
- [ ] Graceful shutdown handling (close WebSocket connections, flush CRDT state)
- [ ] Documentation in README for Docker deployment
- [ ] Container size under 200MB

### Agent Instructions

The production image should contain only the built JavaScript and runtime dependencies. No TypeScript compiler, no dev dependencies, no source maps.

Use `COPY --from=build` pattern for multi-stage builds.

Environment variables should have sensible defaults where possible. Required variables (like OIDC config) should cause the server to fail fast on startup with a clear error message if missing.
