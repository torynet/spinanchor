# Feasibility Study: Real-Time Collaborative Markdown Wiki with Git-Backed Storage

## Executive Summary

Building a Confluence-like system with real-time collaborative editing, backed by a database for live state and git for versioned markdown persistence, is **feasible with well-understood trade-offs**. The key architectural insight is that the database/CRDT layer handles real-time collaboration, while git serves as the versioning and portability layer — committed to on explicit user "publish" actions, not continuously. This draft/publish model (similar to Confluence) eliminates the hardest problems around git lock contention and commit frequency, and produces a git history of intentional, meaningful document versions rather than incidental mid-edit snapshots.

The primary value proposition is broad, accessible editing with simple, portable storage formats (markdown + git) — not live editing for its own sake. Real-time collaboration exists primarily to eliminate the need for checkouts, merges, and conflict resolution from the user's workflow. The system should feel like a wiki, not a version control tool.

No existing open-source project successfully combines all of these capabilities, making this a genuinely novel product if built.

---

## Architecture Overview

### The Draft/Publish Model

The system uses a two-tier persistence model:

1. **Live tier (database + CRDT)**: The authoritative source of truth during editing. A CRDT library (Yjs) handles real-time multi-user collaboration. The database stores document drafts, CRDT state, user sessions, metadata, and indices.

2. **Published tier (git + markdown)**: When a user explicitly publishes, the current document state is serialized to a `.md` file and committed to git. The git history represents a sequence of intentional, reviewed document versions — not a stream of auto-saves.

This mirrors Confluence's model: edits happen in a draft space, and "Publish" creates the canonical version. The git repo becomes a fully portable, human-readable archive of every published version of every document.

**Publish granularity is per-document.** Each publish commits a single file. Since each file has exactly one current state and one draft state at any time, concurrent publishes of different documents can never produce merge conflicts — they touch different paths. A simple per-file mutex is sufficient to prevent the rare case of simultaneous publishes of the same document.

```
┌─────────────────────────────────────────────────────┐
│                    Clients                          │
│   (Browser-based editor with Yjs + rich markdown)  │
└──────────────┬──────────────────────────────────────┘
               │ WebSocket (Yjs sync protocol)
               ▼
┌─────────────────────────────────────────────────────┐
│              Collaboration Server                   │
│                                                     │
│  ┌─────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │ Yjs Doc │  │ Session  │  │ Auth / Permissions│  │
│  │ Manager │  │ Manager  │  │                   │  │
│  └────┬────┘  └──────────┘  └───────────────────┘  │
│       │                                             │
│  ┌────▼────────────────────────────────────────┐    │
│  │  Database (source of truth during editing)  │    │
│  │  - CRDT state per document                  │    │
│  │  - Draft content                            │    │
│  │  - Search index (FTS5)                      │    │
│  │  - Backlinks / link graph                   │    │
│  │  - User attribution log                     │    │
│  │  - CRDT operation logs (fine-grained audit) │    │
│  └────┬────────────────────────────────────────┘    │
│       │                                             │
│       │  on explicit "Publish"                      │
│       ▼                                             │
│  ┌─────────────────────────────────────────────┐    │
│  │  Git Persistence Layer                      │    │
│  │  - Serialize document → .md file            │    │
│  │  - Commit with author attribution           │    │
│  │  - Push to remote (optional)                │    │
│  │  - Detect & reconcile external changes      │    │
│  │  - Git LFS for binary assets (optional)     │    │
│  └─────────────────────────────────────────────┘    │
│       │                                             │
│       ▼                                             │
│  ┌──────────┐                                       │
│  │ Git Repo │  ← also accessible via git CLI,       │
│  │ (.md)    │    IDE, GitHub, etc.                   │
│  └──────────┘                                       │
└─────────────────────────────────────────────────────┘
```

---

## Challenge Analysis

### 1. Real-Time Collaborative Editing

**Status: Solved problem, strong library ecosystem.**

The dominant approach is CRDTs (Conflict-Free Replicated Data Types), which allow multiple users to edit simultaneously without a central coordination server resolving every operation.

**Recommended: Yjs.** It's the most mature and performant CRDT library available — benchmarked at ~5,000x faster than Automerge for text operations. It supports plain text, XML fragments, maps, and arrays. The `y-websocket` package handles the sync protocol.

**Recommended editor: Milkdown.** Milkdown is a markdown-first editor framework built on ProseMirror (for editing) and Remark (for markdown processing), with first-class Yjs collaboration support via its collab plugin. Unlike editors where markdown is an afterthought export format, Milkdown's internal model is designed around markdown serialization — exactly what's needed for clean `.md` output. It's MIT-licensed with no paid tiers, lightweight (~40KB gzipped), and has a clean plugin architecture. ProseMirror directly (also MIT) is the fallback if Milkdown proves too opinionated.

**Automerge** is an alternative CRDT with a richer JSON-based data model but carries significant metadata overhead (a single character can cost hundreds of bytes internally). **Loro** is a newer high-performance option using the Fugue algorithm, but less battle-tested.

For a wiki/knowledge-base use case, users edit via a rich-text interface (rendered markdown, not raw syntax), which sidesteps the thornier CRDT-on-raw-markdown issues. The CRDT operates on the editor's internal document model, and markdown is only a serialization format for persistence.

### 2. Git Persistence on Publish

**Status: Straightforward with the draft/publish model.**

Since git commits only happen on explicit publish actions (human-speed events, minutes or hours apart), the performance constraints that would plague real-time commits are eliminated:

- **No lock contention**: Publishes are infrequent enough that a simple per-file mutex is sufficient. Each publish commits a single document, so concurrent publishes of different files never conflict.
- **No commit frequency ceiling**: You're doing maybe a few commits per minute across the entire system, not hundreds per second.
- **Clean git history**: Each commit represents a deliberate document version, with a meaningful diff. This is far more useful for auditing than thousands of auto-save micro-commits.
- **Author attribution**: The publishing user is the commit author. If multiple people co-edited the draft, co-author trailers can attribute all contributors.

**Git implementation options:**

- **isomorphic-git** (JavaScript, MIT): Recommended. Pure JavaScript, no native dependencies, works in Node.js and browsers. Slower than native implementations, but since publishes are human-speed events (minutes apart), the performance difference is irrelevant. Keeps the entire stack as pure TypeScript/JavaScript with zero compilation requirements.
- **git CLI**: Fallback option. Simplest to implement, spawns a child process per operation. Fine for publish frequency.
- **libgit2** (C library, GPL-2.0 w/ linking exception): Best raw performance via NodeGit bindings, but introduces native compilation dependencies (node-gyp, Python, cmake) that significantly complicate deployment. Not recommended unless benchmarking reveals isomorphic-git is insufficient.
- **gitoxide** (Rust, MIT/Apache-2.0): 6-30% faster than libgit2, but not yet at 1.0, has no language bindings outside Rust, and is still missing key features like push. Not yet practical.

**Repository scale considerations**: GitHub recommends repos under 1GB. A markdown wiki would need to be exceptionally large to approach this — even 10,000 documents at 50KB each is only 500MB. Commit history depth can slow `log` and `blame` over time, but periodic `git gc` and shallow clones for new replicas address this.

### 3. Conflict Resolution: Live Editor vs. External Git Edits

**Status: The most architecturally interesting challenge. Solvable with clear precedence rules.**

The system has two entry points for changes: the live collaborative editor (via the web UI) and direct git operations (via CLI, IDE, GitHub PR, etc.). The main branch is canonical — any commits that land on main are accepted as authoritative and must be ingested into the database.

#### Scenario A: External git change arrives while no one is editing in-app

Simplest case. The server detects the new commit (via polling, webhook, or `post-receive` hook), reads the updated `.md` file, and loads it into the database as the new current state. The CRDT state for that document is reset. No conflict.

#### Scenario B: External git change arrives while someone IS editing in-app

The default behavior is to inject the external changes into the live CRDT session:

1. The server detects the external commit on main.
2. It compares the externally changed `.md` file against the last-published version (the common ancestor).
3. It computes a diff (the external user's changes).
4. It notifies the in-app editors that an external change has arrived.
5. The changes are injected into the CRDT session as operations from a synthetic "external" user.
6. The CRDT merges them automatically — this is exactly what CRDTs are designed for.
7. Live editors see the external changes appear in their editor, as if a new collaborator typed them.

**User experience**: Because the editor is a real-time collaborative environment, users already have the ability to see and react to changes as they appear. External changes arriving is functionally identical to another person joining the editing session and making edits. The editor's existing UX handles this naturally.

**Stash capability**: The system should also offer the option for a user to "stash" their current draft state before external changes are applied — essentially snapshotting their work-in-progress so they can return to it if the external changes cause problems. This could be as simple as a notification: "External changes have arrived for this document. [Accept into draft] [Stash my draft first]". The default should be to accept (since the live editor handles concurrent changes gracefully), but the stash option provides a safety net.

Step 4/5 is the non-trivial implementation part — converting a text diff into CRDT insert/delete operations — but Yjs has APIs for programmatic text manipulation that make this feasible.

#### Scenario C: Live editor publishes while an external commit is in flight

First commit to land on main wins. The second operation discovers the repo has moved ahead and must reconcile. For the live editor, this means fetching the external change, merging via the CRDT (as in Scenario B), and then re-publishing. For an external git user, this is standard git: their push is rejected, they pull, resolve conflicts in their editor, and push again.

### 4. Search

**Status: Solved problem.**

**Recommended: SQLite FTS5.** Zero external dependencies, embedded in the application process, supports BM25 relevance ranking, and can be incrementally updated as documents are published. For a markdown wiki, you'd maintain a full-text index keyed on document path, with the rendered text content (not raw markdown syntax) as the indexed body. Frontmatter fields (tags, author, date) can be indexed separately for filtered queries.

**Alternatives for larger deployments:**

- **MeiliSearch** (MIT community edition): Lightweight self-hosted search server with typo tolerance and faceted search. Good upgrade path if SQLite FTS becomes limiting.
- **Elasticsearch/OpenSearch**: Proven at massive scale but operationally heavy. Unlikely to be needed for a wiki.
- **Client-side (lunr.js, Flexsearch)**: Viable for small wikis (<1,000 documents) and avoids any server-side search infrastructure.

The search index should rebuild from the git repo's markdown files on startup (ensuring the index is always derivable from the source of truth) and update incrementally on each publish.

### 5. Document Interlinking

**Status: Well-understood, implementation straightforward.**

Obsidian-style `[[Page Name]]` wiki-links are the natural fit. Implementation requires:

- **Link resolver**: Maps display names to file paths. Should be case-insensitive and handle aliases (via YAML frontmatter `aliases:` field). Ambiguous links (multiple files match) should surface a warning in the editor.
- **Backlinks index**: For any document, what other documents link to it. Stored in SQLite alongside the search index. Updated on publish.
- **Graph visualization** (optional): The link graph can power a visual knowledge map, similar to Obsidian's graph view.

#### The Rename Problem

**Renames are a separate, exclusive operation.** A document cannot be renamed and edited at the same time. This simplification avoids an entire class of race conditions and keeps the implementation clean.

When a user renames a document via the UI:

1. Any active editing sessions on that document are closed (or blocked from starting).
2. The server renames the file.
3. The server finds all documents containing `[[Old Name]]` links (via the backlinks index).
4. All affected documents that are NOT currently being edited are updated with the new link text.
5. For affected documents that ARE being edited: the link update is injected into the CRDT session as an operation, so live editors see the reference update in real time.
6. The rename and all link updates are committed atomically as a single git commit.

For renames done via git directly (e.g., `git mv`), the server detects the rename on the next poll/hook, updates the backlinks index, but does **not** auto-update links in other files — that would be the system making unsolicited commits. Instead, it flags broken links for an editor to fix.

### 6. Change Auditing

**Status: Git provides this nearly for free. CRDT logs provide the fine-grained supplement.**

With the draft/publish model, git delivers clean audit capabilities:

- **Who** changed a document: the commit author (the publishing user). Co-author trailers for multi-contributor drafts.
- **What** changed: `git diff` between consecutive published versions.
- **When**: commit timestamps.
- **Full history**: `git log -- path/to/document.md` shows every published version of any document.
- **Rollback**: `git revert` or `git checkout <hash> -- path/to/document.md` restores any prior version.

#### Drill-Down Audit UI

The system can present a two-level audit interface:

1. **Published version timeline** (git-backed): Shows a chronological list of published versions for a document, with diffs between them, author, and timestamp. This is the primary audit view — human-readable, portable, and backed by git.

2. **Intra-draft detail view** (CRDT-backed): Clicking into any published version expands to show the CRDT operation log for the editing session that produced it. This reveals who typed what, when, at character-level granularity. Think of it as a playback of the editing session — like git blame but at a much finer resolution.

The CRDT operation logs should be stored in the database with a retention policy (e.g., 90 days of detailed logs, then discard — the git-level audit is permanent). Logs can grow large for heavily-edited documents, so compressed storage is advisable.

---

## Permissions Model

### Design Principle: Space-Level Defaults, Page-Level Overrides

The permission model is role-based (RBAC) with two levels of granularity:

1. **Space-level permissions** (primary): Each space has a set of roles assigned to users or groups. These permissions are inherited by all pages within the space.
2. **Page-level restrictions** (override): Individual pages can have additional restrictions that narrow access beyond what the space allows. A page can never grant *more* access than its containing space — restrictions are subtractive only.

### Roles

Four built-in roles, ordered by increasing privilege:

- **Viewer**: Can read published content. Cannot see drafts or edit.
- **Commenter**: Viewer + can add comments and annotations (v2).
- **Editor**: Commenter + can create/edit pages, publish, and rename. The core contributor role.
- **Admin**: Editor + can manage space settings, permissions, templates, and integrated branches. Can delete pages.

Roles are assigned per-space. A user can be an Admin in one space and a Viewer in another. Group-based assignment (e.g., "Engineering team gets Editor on the Engineering space") reduces management overhead.

### Page-Level Restrictions

Any Editor or Admin can add restrictions to a specific page:

- **View restriction**: Only named users/groups can view this page (others in the space cannot).
- **Edit restriction**: Only named users/groups can edit this page (other Editors in the space can view but not edit).

This mirrors Confluence's model and is sufficient for most team wiki use cases. More granular models (row-level, property-level) add significant complexity and can be deferred.

### Authentication

OAuth2 / OIDC is the authentication layer. The system does not manage passwords. Users authenticate via an external identity provider (Google, Azure AD, Okta, Keycloak, Authentik, etc.). The admin configures the OIDC provider during setup.

Group membership can be synced from the identity provider via OIDC claims or SCIM, reducing manual permission management.

### Git-Level Implications

Permissions exist only in the application layer. The git repo itself has no access controls — anyone who can clone the repo can read everything. This is an intentional trade-off: the git repo is the portable, open backup. If sensitive content exists, the admin should either restrict git repo access at the hosting level (private repo, SSH keys) or accept that the git repo is the "open" tier and page-level restrictions only apply in the web UI.

---

## Organization: Spaces, Tags, and Links

### Three Organizational Layers

The system uses three complementary organizational mechanisms rather than forcing everything into a single hierarchy:

1. **Spaces** (structural): Top-level organizational boundaries that map to folders in the git repo. A space is a collection of related documents — e.g., "Engineering," "Product," "HR Policies." Spaces are also the primary permission boundary. In git, a space is simply a top-level directory.

2. **Tags** (navigational): The primary way users discover and filter content within and across spaces. Documents can have multiple tags (via YAML frontmatter `tags:` field). Tags support nesting via `/` separators (e.g., `architecture/decisions`, `architecture/diagrams`). The UI's primary navigation should be tag-based — browse by tag, filter by tag, tag clouds — rather than forcing users to navigate a folder tree.

3. **Wiki-links and backlinks** (relational): The connective tissue between documents. `[[Page Name]]` links create explicit relationships. The backlinks index surfaces implicit relationships ("what links here?"). An optional graph view visualizes the link topology.

### Why Not Pure Folders?

Git repos require file paths, so there's a filesystem structure. But folders force single-dimensional organization: a document about "API Authentication" could belong in "Engineering," "Security," or "API Reference." Folders make you choose one. Tags let it live in all three.

The git repo structure is intentionally shallow: `{space}/{document-slug}.md`. Sub-folders within a space are allowed but not the primary navigation mechanism. Tags and links carry the organizational weight.

### Frontmatter Convention

Every document has YAML frontmatter that stores metadata indexed by the application:

```yaml
---
title: API Authentication Guide
tags:
  - architecture/decisions
  - security
  - api-reference
aliases:
  - Auth Guide
  - API Auth
author: jane.doe
created: 2026-03-15
---
```

Tags, aliases, and other metadata are indexed in SQLite for fast lookup. The frontmatter is part of the markdown file and therefore versioned in git.

---

## Comments and Annotations

### Design Principle: Comments Are Metadata, Not Content

Comments do not belong in the markdown file or in git. They are collaboration metadata stored in the database, anchored to a document (or a specific position within one) by reference. This follows the pattern established by Google Docs, Notion, and the W3C Web Annotation standard.

### Architecture

Each comment is a database record with:

- `comment_id`: unique identifier
- `page_id`: the document this comment belongs to
- `anchor`: a reference to a specific position or range in the document (nullable — page-level comments have no anchor)
- `author`: the commenting user
- `created_at`, `updated_at`: timestamps
- `content`: the comment text (supports basic formatting)
- `thread_id`: groups replies into a discussion thread
- `resolved`: boolean — resolved comments can be hidden from the default view

### Anchoring to Document Positions

The tricky part is maintaining comment anchors as the document is edited. If a comment points to "paragraph 3, characters 15-30" and someone inserts a paragraph above it, the anchor becomes stale.

Options for anchor stability:

- **CRDT position references**: Yjs assigns stable IDs to every character position. Comments can anchor to these IDs, which survive edits. However, these IDs are only meaningful during an active CRDT session — they don't persist in the markdown.
- **Text-based anchoring**: Store the quoted text the comment was attached to, plus surrounding context. Re-resolve the anchor on each page load by searching for the quoted text. This is how Hypothesis (the web annotation tool) works. It's fuzzy but resilient to edits.
- **Block-level anchoring** (simpler): Anchor comments to block-level elements (paragraphs, headings, list items) rather than character ranges. Less precise but much more robust.

**Recommendation for v1**: Block-level anchoring for inline comments, plus page-level comments with no anchor. Character-level anchoring can be a v2 enhancement.

### What Happens on Export

When a document is exported as markdown (or viewed in the git repo), comments are absent — they exist only in the application. This is intentional: the markdown in git is clean content, not cluttered with annotation markup.

---

## Markdown Flavor and Extensions

### Base: CommonMark + GFM

The system uses CommonMark as the base markdown specification, extended with GitHub Flavored Markdown (GFM) for tables, task lists, strikethrough, and footnotes. This is the most widely supported and portable markdown flavor.

### Extensions

All of the following are supported by the Remark plugin ecosystem and compatible with Milkdown:

| Feature | Remark Plugin | Notes |
|---------|--------------|-------|
| Tables | `remark-gfm` | GFM pipe tables |
| Task lists / checkboxes | `remark-gfm` | `- [ ]` / `- [x]` syntax |
| Strikethrough | `remark-gfm` | `~~text~~` |
| Footnotes | `remark-gfm` | `[^1]` syntax |
| Mermaid diagrams | `remark-mermaid` | Renders ````mermaid` code blocks; vital for technical documentation |
| Callouts / admonitions | `remark-callouts` | Obsidian-compatible `> [!note]` blockquote syntax |
| Math (LaTeX) | `remark-math` + `rehype-katex` | `$inline$` and `$$block$$` math; KaTeX for rendering performance |
| Wiki-links | Custom plugin | `[[Page Name]]` and `[[Page Name|Display Text]]` syntax |

### Mermaid Support

Mermaid is critical for technical wikis. Documents contain ````mermaid` fenced code blocks that render as diagrams (flowcharts, sequence diagrams, ERDs, Gantt charts, etc.) in the editor and read view. The raw markdown is portable — any system that supports Mermaid can render these blocks. In the editor, Milkdown can provide a live preview pane or inline rendering.

### Portability

Because all extensions use standard or widely-adopted markdown syntax (GFM, Obsidian-style callouts, standard fenced code blocks for Mermaid), documents exported from the system render correctly in GitHub, Obsidian, VS Code, and most other markdown tools. This is a key advantage of the markdown-on-git approach.

---

## Notifications and Watchers (Deferred)

A watcher system allows users to subscribe to changes on specific documents, spaces, or tags. When a watched document is published (or receives a comment), subscribed users receive a notification.

### Planned Design

- **Default watcher**: The document author is automatically added as a watcher on creation.
- **Manual subscription**: Any user with view access can watch/unwatch a document.
- **Space-level watches**: Watch all publishes within a space.
- **Tag-level watches**: Watch all documents with a specific tag (useful for "I care about everything tagged `architecture/decisions`").

### Notification Delivery

- In-app notification feed (v2)
- Email digest — configurable frequency: immediate, daily, weekly (v2-v3)
- Webhook / integration endpoint for external systems (v3)

This is a self-contained feature that can be added after the core editing and publishing workflow is stable.

---

## API

### REST + GraphQL

The system should expose a comprehensive API for integrations, automation, and extensibility:

**REST API (v1)**: Standard CRUD endpoints for pages, spaces, tags, comments, search. Authenticated via OAuth2 bearer tokens. Covers all operations available in the UI.

**GraphQL API (v2)**: For flexible querying — e.g., "fetch all pages in the Engineering space tagged `architecture/decisions` with their backlinks and recent comments." GraphQL is particularly well-suited for a wiki's interconnected data model.

### MCP Server (v3)

A Model Context Protocol server allows AI assistants to interact with the wiki as a knowledge source. The MCP would expose:

**Resources** (read-only context):
- `wiki://page/{slug}` — read page content as markdown
- `wiki://search?q={query}` — search pages by content/title
- `wiki://space/{space}/pages` — list pages in a space
- `wiki://tags` — list all tags with page counts

**Tools** (actions):
- `create_page(space, title, content, tags)` — create a new page
- `update_page(slug, content)` — update page content
- `add_comment(slug, content, anchor?)` — add a comment
- `search(query, space?, tags?)` — full-text search with filters
- `get_backlinks(slug)` — find pages that link to a given page

This would make the wiki a first-class knowledge source for AI-assisted workflows — an LLM could search the wiki for context, draft documentation, or answer questions based on the team's knowledge base.

---

## Backup and Disaster Recovery

### What's Already Covered by Design

The architecture provides strong inherent backup properties:

- **Git repo**: Contains the complete published history of every document. If the git repo is pushed to a remote (GitHub, GitLab, Gitea), it's already backed up off-site. Cloning the repo gives you a full copy of all published content and its entire history.
- **Git repo is the recovery baseline**: On startup, the system rebuilds the database (search index, backlinks, published content) from the git repo. If the database is lost but the git repo is intact, only in-progress drafts and CRDT sessions are lost — all published content recovers automatically.

### What Needs Explicit Backup

- **SQLite database**: Contains drafts, CRDT state, comments, user data, permissions, and CRDT operation logs. This is the data that doesn't exist in git. A regular SQLite backup (using SQLite's online backup API or `.backup` command) should be scheduled — daily at minimum, hourly for active deployments.
- **LFS object store** (if using Git LFS): Binary assets stored in S3/MinIO. Standard object storage backup practices apply (versioned buckets, cross-region replication).

### Export

The system should provide an admin export function that produces:

1. A complete clone of the git repo (or a tarball of it)
2. A SQLite database dump
3. An LFS object archive (if applicable)

This bundle is everything needed to restore the system from scratch on a new server. Since the git repo is the foundation and the database is rebuildable from it (minus drafts/comments/permissions), even a partial backup (git repo only) preserves the most critical data.

### Failure Scenarios

| Failure | Data lost | Recovery |
|---------|-----------|----------|
| Database corrupted/lost | Drafts, comments, permissions, CRDT logs | Rebuild from git; re-configure permissions; drafts in progress are lost |
| Git repo corrupted | Published history | Restore from remote (GitHub/GitLab) or backup |
| Both lost | Everything | Restore from export bundle |
| Server crash during CRDT session | In-memory CRDT state since last DB flush | Yjs can persist state to DB periodically (configurable); some recent keystrokes may be lost |

The key insight: **the git repo is the most important thing to back up**, and it's already designed to be cloned/pushed to a remote. If you push to GitHub, you have continuous off-site backup for free.

---

## Templates (Deferred)

Templates are pre-defined document structures that users can select when creating a new page. Common examples: meeting notes, decision records (ADRs), API documentation, incident postmortem, onboarding guide.

A template is simply a markdown file with placeholder content, stored in a dedicated `_templates/` directory within a space (or at the wiki root for global templates). When a user creates a new page from a template, the system copies the template content into the new document's draft.

Templates are versioned in git like any other file. They can be managed via the UI or by editing the `_templates/` directory directly.

This is a straightforward feature that can be added once the core document creation workflow is stable.

---

## Branch Management

### Design Principle: Admin-Controlled Branch Integration

Rather than allowing arbitrary branch creation, the system maintains an **admin-configured list of integrated branches**. Only branches on this list are tracked by the system — the server materializes database state (drafts, CRDT sessions, search indices, backlinks) for each integrated branch.

When a user selects an integrated branch in the UI, they see the wiki content as it exists on that branch. Editing, drafting, and publishing all operate against the selected branch. This enables use cases like:

- A "staging" branch where draft documentation is reviewed before merging to main
- A "v2-docs" branch for a major product version that isn't ready to go live
- Team-specific branches for large documentation efforts

**Key constraints:**

- The admin keeps the list tight. Each integrated branch carries a database footprint (indices, draft state, CRDT sessions for any active editors).
- Database state for an integrated branch can be lazily materialized: built from the git branch content on first access, then cached. Branches not accessed recently can have their database state evicted and rebuilt on demand.
- **Merging branches requires user-driven conflict resolution.** The system can present a diff view and let the user choose per-file or per-hunk (similar to GitHub's conflict resolution UI), but fully automated merge is not realistic for semantic content. This remains the user's responsibility.
- The main branch is always canonical. External commits to main are always accepted and ingested.

### What Branches Are NOT For

Branches are not a substitute for the draft/publish model. Individual document drafts live in the database and don't require branches. Branches are for coordinating sets of related changes across multiple documents that need to be reviewed or staged as a group before going live.

---

## Offline Editing

**Recommendation: Don't build it into the app. Let git handle it.**

Offline editing fundamentally reintroduces the merge conflict problem that real-time collaboration exists to eliminate. CRDTs can technically merge divergent offline edits, but the results can be semantically nonsensical even if they're structurally valid (two people reorganize the same section differently, the CRDT merges both, and the result is incoherent).

Since the entire published state of the wiki lives in a git repo as plain markdown, a user who needs offline access can simply clone the repo and use any markdown editor they prefer. When they push their changes, the system ingests them via the normal external edit detection path. This is simpler, more flexible, and avoids building a degraded-mode offline experience into the web app.

---

## Binary Assets and Git LFS

Images, diagrams, PDFs, and other binary attachments are common in wikis but problematic for git at scale (every version of every binary is stored in full).

**Git LFS (Large File Storage)** addresses this by replacing large files with lightweight text pointers in the git repo, while storing the actual binary content on a separate LFS server. This keeps the repo lean while maintaining the appearance of normal file tracking.

### How It Would Work

1. A user uploads an image to a wiki page via the editor.
2. The server stores the binary via Git LFS: the pointer file goes into the git repo, the actual content goes to the LFS store.
3. The markdown references the asset with a relative path (e.g., `![diagram](assets/architecture.png)`).
4. When viewing the page, the server resolves the LFS pointer and serves the binary content.
5. Git CLI users who clone the repo get the pointers by default and can `git lfs pull` to fetch the actual files.

### Self-Hosted LFS Server Options

All open source:

- **Gitea**: Built-in LFS support with configurable storage backends — local disk or any S3-compatible object store (AWS S3, MinIO, DigitalOcean Spaces).
- **soft-serve** (Charm): Self-hostable git server with LFS support over both SSH and HTTP.
- **giftless**: Standalone Python LFS server with pluggable storage backends.

For this system, the simplest approach is to either embed LFS handling in the application server (implementing the LFS HTTP API to proxy to an S3-compatible store) or run a lightweight LFS server (like giftless) alongside the application.

### Storage Implications

- Git repos stay small because only pointer files are committed.
- Cloning is fast — LFS objects are fetched on demand.
- LFS content can live on cheap object storage (S3, MinIO) rather than in the git object database.
- `git diff` on LFS-tracked files shows pointer changes, not binary diffs. The application UI would need to show visual diffs (e.g., side-by-side image comparison) separately.

---

## Existing Projects and Their Trade-Offs

| Project | Real-time collab | Git storage | Plain markdown | Search | Key limitation |
|---------|:---:|:---:|:---:|:---:|--------|
| **Wiki.js** | No | Git sync (delayed) | Markdown on disk | Built-in | Closest overall, but git sync is fragile and delayed (5-min default); no real-time collab |
| **HedgeDoc** | Yes (OT) | No | Markdown in DB | Limited | No git integration |
| **Gollum** | No | Git-native | Markdown | Basic | Slow at scale (2-3s/page load) |
| **Outline** | Yes (Prosemirror) | No | Markdown export | Full-text | DB-only, no git |
| **SilverBullet** | Yes (multi-user) | Plugin only | Markdown | Yes | Local-first PKM; git via optional plugin, not a team wiki |
| **BookStack** | No | No | HTML in DB | Full-text | No markdown, no git |
| **Foam/Dendron** | No | Git (user-managed) | Markdown | VS Code search | Local-only, no web UI |
| **Obsidian** | Paid sync only | No (plugins) | Markdown | Excellent | Local-first, proprietary sync |
| **GitBook** | No | Git | Markdown | Good | Commercial, limited self-host |

**Wiki.js comes closest** by combining git sync with markdown storage and a built-in editor, but its git integration is asynchronous and reportedly fragile in production (sync failures, unstaged file conflicts, force-sync issues). It also lacks true real-time collaborative editing. The proposed system would address all of these gaps.

---

## Dependency Licensing

All recommended dependencies are permissively licensed with no paid tiers:

| Library | License | Notes |
|---------|---------|-------|
| Yjs | MIT | |
| y-websocket | MIT | |
| Milkdown | MIT | Markdown-first editor; no paid tier |
| ProseMirror | MIT | Underlies Milkdown |
| Remark (unified) | MIT | Markdown processing; underlies Milkdown |
| isomorphic-git | MIT | Pure JavaScript git implementation |
| SQLite | Public domain | Built into Node.js 22+ via `node:sqlite` |

**All MIT or public domain. No copyleft, no paid tiers, no licensing complications for an open-source project.**

Alternatives evaluated but not recommended:

| Library | License | Why not recommended |
|---------|---------|---------------------|
| TipTap | MIT core, paid Pro | Collaborative editing extensions require paid subscription — incompatible with open-source |
| libgit2 / NodeGit | GPL-2.0 w/ linking exception | Introduces native compilation dependencies; isomorphic-git is sufficient |
| MeiliSearch | MIT community, BUSL enterprise | SQLite FTS5 is sufficient and avoids a separate service |

---

## Technology Consolidation

### One Language, Minimal Dependencies

A key advantage of the recommended stack is that **every dependency is pure TypeScript/JavaScript** with zero native compilation requirements (assuming Node.js 22+):

| Layer | Library | Language | Native deps? |
|-------|---------|----------|:---:|
| CRDT | Yjs, y-websocket | JavaScript | No |
| Editor | Milkdown | TypeScript | No |
| Editor engine | ProseMirror | TypeScript | No |
| Markdown processing | Remark (unified) | JavaScript | No |
| Git operations | isomorphic-git | JavaScript | No |
| Database + search | `node:sqlite` (FTS5) | Built into Node 22+ | No |
| Server runtime | Node.js | TypeScript | — |

This means: no node-gyp, no Python build tooling, no cmake, no C compilation. The Docker image is a plain Node.js base image with application code copied in. CI/CD is trivial. Cross-platform development works without platform-specific build chains.

The entire technology surface is **TypeScript on Node.js**. A contributor needs to know one language and one runtime.

### Why Not Native Dependencies?

The two places where native libraries were considered (libgit2 for git, better-sqlite3 for SQLite) offer better raw performance but introduce significant deployment friction. Since git operations happen at human speed (publishes are minutes apart) and SQLite is embedded in Node.js 22+, the pure-JS alternatives sacrifice negligible performance for dramatically simpler builds and deployments.

If benchmarking later reveals a bottleneck, native dependencies can be introduced selectively without architectural changes.

---

## Infrastructure Requirements

### Design Goal: Maximum Portability

The system is designed to run on any infrastructure with minimal external dependencies.

### Core Components (Single Container)

The entire application can run as **a single process with local file storage**:

- **Application server** (Node.js 22+): Handles WebSocket connections, CRDT sessions, HTTP API, git operations. Stateless except for active CRDT sessions in memory. All dependencies are pure JavaScript — no native compilation required.
- **SQLite database** (via `node:sqlite`): Single file on disk. Covers drafts, CRDT state, search index (FTS5), backlinks, user data, audit logs. No separate database server required. Built into the Node.js runtime.
- **Git repository**: A directory on disk (or a mounted volume). Managed via isomorphic-git (pure JavaScript).

That's one container with two mounted volumes (SQLite DB file + git repo directory). No PostgreSQL, no Redis, no Elasticsearch, no message queue.

### Optional Components

- **S3-compatible object store** (for Git LFS binary assets): Can be MinIO in a sidecar container for self-hosted deployments, or any cloud S3-compatible service.
- **Reverse proxy** (nginx, Caddy, Traefik): For TLS termination and WebSocket handling in production.
- **Remote git host** (GitHub, GitLab, Gitea): Optional push target for the git repo. Not required — the local repo is fully self-contained.
- **OAuth2 / OIDC provider**: For authentication. Could be a hosted service (Auth0, Google, Azure AD) or self-hosted (Keycloak, Authentik).

### Deployment Model

A realistic production deployment is a `docker-compose.yml` with two or three services:

1. The application (single container)
2. MinIO for LFS storage (optional, if binary assets are needed)
3. A reverse proxy (or use the cloud provider's load balancer)

This runs on any VM, any cloud, any Kubernetes cluster. The admin configures: git remote URL (optional), LFS storage endpoint (optional), and OAuth/OIDC provider for auth.

**For small teams**, the entire system can run on a single $5-20/month VPS with no external dependencies beyond the OAuth provider.

### Scaling Beyond a Single Server

If the system needs to scale beyond what a single server can handle (likely at hundreds of concurrent editors), the main constraint is that CRDT sessions are in-memory on the application server. Options:

- **Sticky sessions**: Route all editors of a given document to the same server instance. Simple, effective for moderate scale.
- **PostgreSQL**: Replace SQLite with PostgreSQL for shared database state across multiple application servers.
- **Redis or NATS**: For CRDT state synchronization between server instances (Yjs supports pluggable persistence and awareness providers).

This is a v2+ concern. A single Node.js server with SQLite can comfortably handle dozens of concurrent editors and thousands of documents. The pure-JavaScript stack means scaling horizontally just requires more identical containers — no native dependency compilation per platform.

---

## Feasibility Assessment

### Solidly achievable (solved problems, strong libraries exist)

- Real-time collaborative editing via Yjs + Milkdown
- Database-backed draft storage with CRDT state
- Git commit on publish with author attribution
- Full-text search via SQLite FTS5
- Wiki-links with backlinks and rename handling
- Change auditing via git history with CRDT drill-down
- Single-container deployment with minimal infrastructure

### Requires care but is tractable

- **External git edit reconciliation** during active sessions: converting text diffs into CRDT operations is non-trivial but Yjs provides the APIs. The notification + stash UX gives users control over how external changes arrive.
- **CRDT-to-markdown serialization fidelity**: if users edit via a rich-text UI (not raw markdown), the editor's internal model maps cleanly to markdown output. Edge cases exist with complex formatting under concurrent edits, but they're rare in wiki-style content.
- **Scaling the git repo**: thousands of documents and tens of thousands of commits are well within git's comfort zone. Periodic GC, shallow clones for replicas, and sparse checkout for large deployments are established techniques.

### Deferred to later versions

- **Comments with inline anchoring** (Phase 2): Database-stored comments with block-level or character-level anchoring.
- **Full external edit reconciliation with CRDT injection** (Phase 2): Phase 1 notifies users and offers stash; Phase 2 adds seamless injection of external changes into live sessions.
- **Audit drill-down UI** (Phase 2): Git-level timeline with CRDT operation log expansion for intra-draft detail.
- **Notifications and watchers** (Phase 2): Author auto-watch, manual subscriptions, in-app feed.
- **Templates** (Phase 2): `_templates/` directory per space with template selection on page creation.
- **Git LFS for binary assets** (Phase 3): Adds operational complexity (LFS server, object storage) but is well-understood.
- **GraphQL API** (Phase 3): Flexible querying for complex integrations.
- **Admin-managed branch integration** (Phase 3): Per-branch database state, lazy materialization, and user-driven merge conflict resolution.
- **MCP server** (Phase 3): Wiki as AI knowledge source via Model Context Protocol.

---

## Recommended Technology Stack

### Option A: TypeScript (Recommended for MVP)

All TypeScript/JavaScript. No native dependencies. One language, one runtime. Fastest path to a working prototype.

| Layer | Technology | License | Rationale |
|-------|-----------|---------|-----------|
| Server runtime | **Node.js 22+** | MIT | Built-in SQLite; Yjs is JS-native; fastest path to prototype |
| Collaborative editing | **Yjs** + **y-websocket** | MIT | Most performant CRDT, battle-tested, great docs |
| Rich-text editor | **Milkdown** (on ProseMirror + Remark) | MIT | Markdown-first design; official Yjs collab plugin; no paid tiers |
| Database + search | **node:sqlite** with **FTS5** | Public domain | Built into Node 22+; zero-config; no native compilation |
| Git operations | **isomorphic-git** | MIT | Pure JavaScript; no native deps; sufficient for publish-speed operations |
| Auth | **OAuth2 / OIDC** | N/A (protocol) | Standard, integrates with existing identity providers |
| Binary assets (v2) | **Git LFS** + S3-compatible store | MIT | Keeps git repo lean; MinIO for self-hosted storage |

### Option B: Rust Server + TypeScript Client

Two languages, but with significant performance and safety advantages. The browser client remains TypeScript regardless — only the server changes.

| Layer | Technology | License | Rationale |
|-------|-----------|---------|-----------|
| Server runtime | **Rust** (via **axum**) | MIT | Community-standard Rust web framework; backed by Tokio team; first-class WebSocket support |
| Collaborative editing | **yrs** + **yrs-tokio** | MIT | Rust port of Yjs; wire-compatible with Yjs browser clients; same sync protocol |
| Rich-text editor | **Milkdown** (on ProseMirror + Remark) | MIT | Unchanged — runs in the browser as TypeScript |
| Database + search | **rusqlite** + **fsqlite-ext-fts5** | MIT | Mature Rust SQLite bindings; FTS5 via additional crate |
| Git operations | **gitoxide** | MIT / Apache-2.0 | Rust-native git; 6-30% faster than libgit2; actively closing feature gaps |
| Auth | **OAuth2 / OIDC** | N/A (protocol) | Standard, integrates with existing identity providers |
| Binary assets (v2) | **Git LFS** + S3-compatible store | MIT | Keeps git repo lean; MinIO for self-hosted storage |

**What the Rust option gives you:**
- Memory safety and fearless concurrency — relevant for a server managing many simultaneous CRDT sessions
- Lower memory footprint and CPU usage at scale (smaller/cheaper containers)
- Compile-time guarantees that eliminate entire classes of runtime bugs
- gitoxide as a native, high-performance git implementation instead of isomorphic-git
- Smaller Docker images (static Rust binary vs. full Node.js runtime)

**What it costs:**
- Two language ecosystems: Rust (Cargo) for the server + TypeScript (npm/bundler) for the browser client. Contributors need both.
- Slower development iteration: Rust's compile cycle is longer; prototyping is less fluid than TypeScript.
- Estimated 20-30% slower time to MVP (more if the team is learning Rust).
- FTS5 support requires an additional crate (`fsqlite-ext-fts5`) rather than being built into the runtime.

**Key compatibility detail:** yrs (Rust) and Yjs (JavaScript) use the same binary sync protocol. A Milkdown editor in the browser running Yjs connects to a Rust server running yrs over WebSocket with zero translation layer. This is explicitly supported and tested via the `yrs-tokio` crate.

**Migration path:** Start with Option A (TypeScript) for the MVP. If performance or concurrency becomes a concern, rewrite the server in Rust (Option B) without changing the browser client, the database schema, or the git repo structure. The WebSocket protocol is compatible in both directions. This is not a one-way door.

---

## Recommended Build Sequence

### Phase 1: Core (MVP)

1. **Core editor**: Yjs + Milkdown with y-websocket. Multiple users can edit a document in real-time. Documents stored in SQLite via `node:sqlite`. Markdown extensions: GFM (tables, task lists, footnotes), Mermaid, callouts, math.
2. **Git persistence**: On publish, serialize to `.md` with YAML frontmatter and commit (single file per commit). On startup, seed the database from the git repo. Per-file mutex to prevent simultaneous publishes of the same document.
3. **Spaces and tags**: Spaces as top-level git directories. Tags in YAML frontmatter, indexed in SQLite. Tag-based navigation in the UI.
4. **Search**: SQLite FTS5 index, rebuilt from git on startup, updated incrementally on publish.
5. **Wiki-links**: `[[link]]` syntax with backlinks index. Renames as a separate exclusive operation with atomic git commits.
6. **Permissions**: OAuth2/OIDC authentication. Role-based access per space (Viewer, Editor, Admin). Page-level restrictions (subtractive).
7. **REST API**: CRUD endpoints for pages, spaces, tags, search. OAuth2 bearer token auth.
8. **External edit detection**: Poll or hook for commits to main. Accept as canonical. Load changes into database. Notify active editors and offer stash option.

### Phase 2: Collaboration Features

9. **Comments**: Database-stored comments with block-level anchoring. Page-level and inline comments. Discussion threads with resolution.
10. **Audit UI**: Published version timeline from git log. CRDT operation log storage with retention policy and drill-down.
11. **External edit reconciliation**: Inject external diffs into active CRDT sessions seamlessly.
12. **Notifications / watchers**: Author auto-watch on creation. Manual subscription per document, space, or tag. In-app notification feed.
13. **Templates**: `_templates/` directory per space. Template selection on page creation.

### Phase 3: Advanced

14. **Git LFS**: Binary asset handling with S3-compatible storage backend.
15. **GraphQL API**: Flexible querying across pages, tags, backlinks, comments.
16. **Branch integration**: Admin-managed list of tracked branches with per-branch database state, lazy materialization, and user-driven merge conflict resolution.
17. **MCP server**: Expose wiki as a knowledge source for AI assistants via Model Context Protocol.
18. **Email notifications**: Configurable digest (immediate, daily, weekly) for watched content.
