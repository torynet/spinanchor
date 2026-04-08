# spinanchor

A real-time collaborative markdown wiki with git-backed storage.

## What Is This?

An open-source knowledge management system that combines:

- **Real-time collaborative editing** — multiple users can edit the same document simultaneously, no merge conflicts
- **Plain markdown storage** — all published content lives as `.md` files in a git repository
- **Git-backed versioning** — every publish creates a meaningful git commit with full audit history
- **Wiki-style linking** — `[[Page Name]]` links with backlinks, search, and tag-based navigation
- **Portable by design** — clone the repo and you have every published version of every document in plain text

Think Confluence, but open source, backed by markdown and git, with real-time collaboration.

## Status

**Pre-development** — Architecture and planning phase. See the [plan/](plan/) directory for design documents.

## Architecture

The system uses a two-tier persistence model:

1. **Live tier**: A database + CRDT layer (Yjs) handles real-time collaborative editing. This is the source of truth during active editing sessions.
2. **Published tier**: When a user clicks "Publish," the document is serialized to markdown and committed to git. The git history contains only intentional, reviewed versions.

See [plan/architecture.md](plan/architecture.md) for full details.

## Technology Stack

- **Editor**: Milkdown (ProseMirror + Remark) with Yjs collaboration
- **Server**: Node.js 22+ (TypeScript)
- **Database**: SQLite via `node:sqlite` (FTS5 for search)
- **Git**: isomorphic-git (pure JavaScript)
- **Auth**: OAuth2 / OIDC

All dependencies are pure TypeScript/JavaScript with no native compilation required.

## License

[Blue Oak Model License 1.0.0](LICENSE.md)
