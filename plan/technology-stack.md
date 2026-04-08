# Technology Stack

## Primary Stack: TypeScript on Node.js

All dependencies are pure TypeScript/JavaScript with zero native compilation requirements.

| Layer | Technology | License | Why |
|-------|-----------|---------|-----|
| Server runtime | Node.js 22+ | MIT | Built-in SQLite; Yjs is JS-native |
| CRDT | Yjs + y-websocket | MIT | Most performant CRDT; battle-tested |
| Editor | Milkdown (ProseMirror + Remark) | MIT | Markdown-first; official Yjs collab plugin; no paid tiers |
| Database + Search | `node:sqlite` with FTS5 | Public domain | Built into Node 22+; zero-config |
| Git operations | isomorphic-git | MIT | Pure JavaScript; no native deps |
| Auth | OAuth2 / OIDC | Protocol | Standard; works with any identity provider |
| Binary assets (Phase 3) | Git LFS + S3-compatible store | MIT | MinIO for self-hosted storage |

### Markdown Extensions (Remark Plugins)

| Feature | Plugin | Notes |
|---------|--------|-------|
| Tables, task lists, footnotes, strikethrough | `remark-gfm` | GFM extensions |
| Mermaid diagrams | `remark-mermaid` or client-side Mermaid JS | Vital for technical docs |
| Callouts / admonitions | `remark-callouts` | Obsidian-compatible `> [!note]` syntax |
| Math (LaTeX) | `remark-math` + `rehype-katex` | KaTeX for rendering performance |
| Wiki-links | Custom plugin | `[[Page Name]]` syntax |

## Alternative Stack: Rust Server

Documented as an option for future migration. The browser client remains TypeScript regardless.

| Layer | Technology | License | Notes |
|-------|-----------|---------|-------|
| Server runtime | Rust (axum) | MIT | Tokio-backed; first-class WebSocket |
| CRDT | yrs + yrs-tokio | MIT | Wire-compatible with Yjs browser clients |
| Database | rusqlite + fsqlite-ext-fts5 | MIT | FTS5 via additional crate |
| Git | gitoxide | MIT / Apache-2.0 | Rust-native; not yet 1.0 |

The Rust and TypeScript stacks are interchangeable at the server level. The Yjs/yrs sync protocol is binary-compatible. Migration from TypeScript to Rust can happen without changing the client, database schema, or git repo structure.

## Deployment Infrastructure

Single container. No external services required except an OAuth2/OIDC provider.

| Component | Required? | Notes |
|-----------|-----------|-------|
| Application server | Yes | Single Node.js process |
| SQLite database | Yes | File on mounted volume |
| Git repository | Yes | Directory on mounted volume |
| Reverse proxy (Caddy/nginx) | Production | TLS termination, WebSocket handling |
| S3-compatible store (MinIO) | Phase 3 | For Git LFS binary assets |
| Remote git host (GitHub/GitLab) | Optional | Push target for off-site backup |
| OAuth2/OIDC provider | Yes | Google, GitHub, Azure AD, Keycloak, etc. |
