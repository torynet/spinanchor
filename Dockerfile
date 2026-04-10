FROM node:22-slim AS base
RUN corepack enable

WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY packages/server/package.json packages/server/
COPY packages/client/package.json packages/client/

RUN pnpm install --frozen-lockfile

COPY . .

# Development target
FROM base AS dev
EXPOSE 3000 5173
CMD ["pnpm", "dev"]
