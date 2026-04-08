# Architecture

This document summarizes the system architecture. The full feasibility study with research backing is in `plan/feasibility-study.md`.

## Two-Tier Persistence Model

### Live Tier (Database + CRDT)

The authoritative source of truth during editing. Yjs handles real-time multi-user collaboration. The SQLite database stores:

- CRDT state per document
- Draft content
- Search index (FTS5)
- Backlinks / link graph
- User attribution log
- CRDT operation logs (fine-grained audit)
- Comments and annotations
- Permissions and user data

### Published Tier (Git + Markdown)

When a user explicitly publishes, the current document state is serialized to a `.md` file with YAML frontmatter and committed to git. Each publish commits a single file. The git history represents intentional, reviewed document versions.

## Diagram

```
┌─────────────────────────────────────────────────────┐
│                    Clients                          │
│   (Browser-based editor with Yjs + Milkdown)       │
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
│  │            SQLite Database                  │    │
│  │  (via node:sqlite, built into Node 22+)     │    │
│  └────┬────────────────────────────────────────┘    │
│       │                                             │
│       │  on explicit "Publish"                      │
│       ▼                                             │
│  ┌─────────────────────────────────────────────┐    │
│  │  Git Persistence Layer                      │    │
│  │  (via isomorphic-git, pure JavaScript)      │    │
│  └─────────────────────────────────────────────┘    │
│       │                                             │
│       ▼                                             │
│  ┌──────────┐                                       │
│  │ Git Repo │  ← also accessible via git CLI,       │
│  │ (.md)    │    IDE, GitHub, etc.                   │
│  └──────────┘                                       │
└─────────────────────────────────────────────────────┘
```

## Key Design Decisions

1. **Yjs is the source of truth** during active editing sessions. Git is the persistence layer.
2. **Publish is per-document**, creating a single-file commit. Concurrent publishes of different documents never conflict.
3. **Main branch is canonical**. External commits to main are accepted and ingested into the database.
4. **Renames are exclusive operations**. A document cannot be renamed and edited simultaneously.
5. **Comments are database-only metadata**, never written to markdown or git.
6. **Spaces map to top-level git directories**. Tags (in YAML frontmatter) are the primary navigation mechanism.
7. **The database rebuilds from git on startup**. Only drafts, comments, permissions, and CRDT logs require separate backup.

## Technology Stack

See `plan/technology-stack.md` for details and alternatives.

| Layer | Technology | License |
|-------|-----------|---------|
| Server | Node.js 22+ (TypeScript) | MIT |
| CRDT | Yjs + y-websocket | MIT |
| Editor | Milkdown (ProseMirror + Remark) | MIT |
| Database + Search | node:sqlite with FTS5 | Public domain |
| Git | isomorphic-git | MIT |
| Auth | OAuth2 / OIDC | N/A |

All pure TypeScript/JavaScript. No native dependencies.
