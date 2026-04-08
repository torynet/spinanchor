# Project Phases

## Phase 1: Core (MVP)

The minimum viable product. A user can create, edit, publish, search, and link documents collaboratively in real time, with git-backed persistence and role-based permissions.

### 1.1 Project Scaffolding
- Initialize monorepo (pnpm workspaces)
- TypeScript configuration (server + client)
- Vite for client build, tsup/tsx for server
- Vitest for testing
- ESLint + Prettier
- Docker development environment
- CI pipeline (GitHub Actions): lint, test, build

### 1.2 Core Editor
- Milkdown editor integration with ProseMirror + Remark
- Yjs CRDT integration via Milkdown collab plugin
- y-websocket server for real-time sync
- Markdown extensions: GFM (tables, task lists, footnotes), Mermaid, callouts, math (KaTeX)
- Wiki-link syntax (`[[Page Name]]`) support in editor
- Basic page chrome: title, save/publish button, metadata display

### 1.3 Database Layer
- SQLite schema design and migration system
- Document storage: drafts, CRDT state, published content
- FTS5 search index (indexed on publish, rebuilt from git on startup)
- Backlinks index
- Tags index
- User and session tables
- Space and permission tables

### 1.4 Git Persistence
- isomorphic-git integration
- Publish action: serialize Milkdown document → markdown with YAML frontmatter → git commit
- Startup: seed database from git repo (rebuild search index, backlinks, published content)
- Per-file mutex for publish operations
- Git repo initialization on first run

### 1.5 Spaces, Tags, and Navigation
- Space CRUD (create, list, configure)
- Space maps to top-level git directory
- Tag-based navigation UI
- Document list views (by space, by tag, recent, all)
- Backlinks panel on each document

### 1.6 Search
- Full-text search UI
- SQLite FTS5 queries with BM25 ranking
- Filter by space, tag
- Search results with context snippets

### 1.7 Permissions
- OAuth2/OIDC authentication integration
- Role-based access per space (Viewer, Editor, Admin)
- Page-level restrictions (subtractive only)
- Admin UI for managing spaces, users, roles

### 1.8 REST API
- CRUD endpoints: pages, spaces, tags
- Search endpoint
- Publish endpoint
- Authentication via OAuth2 bearer tokens
- OpenAPI spec

### 1.9 External Edit Detection
- Poll for new commits on main (or webhook/hook integration)
- Ingest external changes into database
- Notify active editors when external changes arrive for their document
- Offer stash option before applying external changes
- Accept main as canonical

---

## Phase 2: Collaboration Features

Enhances the collaborative experience with comments, audit tools, notifications, and improved external edit handling.

### 2.1 Comments
- Database-stored comments (page-level and block-level anchoring)
- Comment threads with replies
- Resolved/unresolved state
- Comment indicators in the editor margin
- API endpoints for comments

### 2.2 Audit UI
- Published version timeline (from git log)
- Diff view between any two published versions
- CRDT operation log storage with retention policy
- Drill-down into a publish to see fine-grained edit history (who typed what, when)
- Per-user contribution summary

### 2.3 External Edit Reconciliation
- Convert text diffs from external commits into Yjs CRDT operations
- Inject external changes into active CRDT sessions seamlessly
- Visual indicator in editor showing externally-sourced changes

### 2.4 Notifications and Watchers
- Auto-watch on document creation (author)
- Manual watch/unwatch per document, space, or tag
- In-app notification feed
- Notification preferences per user

### 2.5 Templates
- `_templates/` directory per space (and global)
- Template selection UI on page creation
- Template management in admin UI
- Templates versioned in git like any other file

---

## Phase 3: Advanced Features

Extends the system with binary asset support, advanced API, branch management, and AI integration.

### 3.1 Git LFS for Binary Assets
- Git LFS integration for images, PDFs, attachments
- Image upload in editor → LFS storage
- S3-compatible backend (MinIO for self-hosted)
- LFS pointer resolution for serving assets
- Admin configuration for LFS storage endpoint

### 3.2 GraphQL API
- Schema design covering pages, spaces, tags, backlinks, comments, users
- Flexible querying (e.g., "all pages in space X with tag Y and their backlinks")
- Subscription support for real-time updates (optional)

### 3.3 Branch Integration
- Admin-managed list of integrated branches
- Per-branch database state (lazy materialization)
- Branch selector in UI
- User-driven merge conflict resolution UI
- Database state eviction for inactive branches

### 3.4 MCP Server
- Model Context Protocol server exposing wiki as knowledge source
- Resources: page content, search, space listing, tags
- Tools: create/update pages, add comments, search
- Enables AI assistants to read/write wiki content

### 3.5 Email Notifications
- Configurable digest frequency (immediate, daily, weekly)
- Email templates
- SMTP configuration in admin
- Unsubscribe links

### 3.6 Advanced Permissions
- Commenter role (view + comment, no edit)
- Group management UI (beyond OIDC sync)
- Audit log for permission changes
