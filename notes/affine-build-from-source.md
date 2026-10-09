# Building AFFiNE from Source

How we got AFFiNE self-hosted and running, built from the submodule source rather than the pre-built ghcr.io image.

## Setup

AFFiNE is checked out as a git submodule at `./AFFiNE`:

```sh
git submodule add https://github.com/toeverything/AFFiNE
```

The stack is defined in two files:
- `Dockerfile.affine` - multi-stage build from source
- `docker-compose.affine.yml` - service orchestration (server, migration, redis, postgres)

## Running

```sh
# First build (takes ~90 minutes due to Rust native modules + frontend builds)
docker compose -f docker-compose.affine.yml up -d --build

# Subsequent runs (uses cache)
docker compose -f docker-compose.affine.yml up -d

# Force full rebuild
docker compose -f docker-compose.affine.yml build --no-cache
docker compose -f docker-compose.affine.yml up -d --force-recreate
```

AFFiNE will be available at `http://localhost:3010`. First visit redirects to `/admin/setup`.

## Architecture

The Docker build has three stages:

1. **builder** (node:22-bookworm) - installs Rust 1.93, builds native NAPI modules, compiles all frontend apps (web, admin, mobile) and the backend server
2. **assets** (node:22-bookworm-slim) - copies build artifacts and runs `docker-clean.mjs` to strip dev files
3. **runtime** (node:22-bookworm-slim) - minimal image with openssl and jemalloc

The compose stack runs four services:
- `affine` - the main NestJS server on port 3010
- `affine-migration` - one-shot job that runs Prisma migrations before the server starts
- `affine-redis` - session/cache store
- `affine-postgres` - pgvector/pg16 database

## Problems We Hit and How We Fixed Them

### 1. Git repo lookup fails inside Docker

**Error:** `Failed to open git repo: [/app/], reason: failed to resolve path '/app/../.git/modules/AFFiNE'`

**Cause:** AFFiNE's `html-plugin.ts` uses `@napi-rs/simple-git` to get the current commit hash for cache-busting. When the code lives in a git submodule, the `.git` file is a reference to `../../.git/modules/AFFiNE`, which doesn't exist inside the Docker build context (we only `COPY ./AFFiNE /app`).

**Fix:** Set `GITHUB_SHA=docker-build` in the Dockerfile. The `gitShortHash()` function in `tools/cli/src/webpack/html-plugin.ts` checks for `GITHUB_SHA` env var first and skips the git repo lookup when it's set.

### 2. Missing arch-specific native module files

**Error:** `Module not found: Error: Can't resolve './server-native.x64.node'` (also arm64, armv7)

**Cause:** The Rust NAPI build produces `server-native.node`, but AFFiNE's CI pipeline renames it to `server-native.x64.node` (matching the build architecture). The native module loader in `packages/backend/native/index.js` tries to load the base `.node` file first, then falls back to arch-specific names (`.x64.node`, `.arm64.node`, `.armv7.node`). Since webpack resolves all `require()` paths at compile time, **all three arch files must exist** even though only x64 is actually used.

**Fix:** After building the native module, copy it to the x64 name and create empty stubs for the other architectures:
```dockerfile
RUN yarn workspace @affine/server-native build --target x86_64-unknown-linux-gnu \
    && cp packages/backend/native/server-native.node packages/backend/native/server-native.x64.node \
    && touch packages/backend/native/server-native.arm64.node \
    && touch packages/backend/native/server-native.armv7.node
```

Without the stubs, webpack exits with errors and doesn't emit `dist/main.js`, which causes the migration job and server to fail with `Cannot find module '/app/dist/main.js'`.

### 3. Migration container using stale image

**Symptom:** After rebuilding, the migration job still failed because `docker compose up -d` doesn't automatically rebuild images for services that share the same Dockerfile.

**Fix:** Use `--build` flag or explicitly rebuild: `docker compose -f docker-compose.affine.yml up -d --build --force-recreate`

## Environment Variables

Configurable via `.env` or shell environment:

| Variable | Default | Description |
|---|---|---|
| `AFFINE_PORT` | `3010` | Host port for the server |
| `AFFINE_DB_USERNAME` | `affine` | PostgreSQL username |
| `AFFINE_DB_PASSWORD` | `affine` | PostgreSQL password |
| `AFFINE_DB_DATABASE` | `affine` | PostgreSQL database name |

## Skipped Build Downloads

The Dockerfile sets these env vars to skip unnecessary binary downloads during `yarn install`:

- `HUSKY=0` - skip git hooks
- `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` - skip browser binaries
- `ELECTRON_SKIP_BINARY_DOWNLOAD=1` - skip Electron
- `SENTRYCLI_SKIP_DOWNLOAD=1` - skip Sentry CLI
