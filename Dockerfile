ARG RUNTIME_IMAGE=node:22-alpine

# -----------------------------------------------------------------------------
# Base image with pnpm enabled via Corepack so every stage shares the same setup
# -----------------------------------------------------------------------------
FROM ${RUNTIME_IMAGE} AS base

ENV PNPM_HOME=/root/.local/share/pnpm \
    PATH=${PNPM_HOME}:$PATH

WORKDIR /app

# Ensure pnpm is available even if corepack is missing (e.g., if base isn't a Node image)
RUN if command -v corepack >/dev/null 2>&1; then \
      corepack enable pnpm && corepack prepare pnpm@10.20.0 --activate; \
    else \
      echo "corepack not found; attempting to use npm to install pnpm globally" && \
      if command -v npm >/dev/null 2>&1; then \
        npm i -g pnpm@10.20.0; \
      else \
        echo "Error: Neither corepack nor npm is available in the base image. Use a Node base image (e.g., node:22-alpine)." >&2; \
        exit 1; \
      fi; \
    fi

# -----------------------------------------------------------------------------
# Install dependencies with a frozen lockfile for reproducible builds
# -----------------------------------------------------------------------------
FROM base AS deps

# Tools needed for native module compilation when required by dependencies
RUN apk add --no-cache python3 make g++

COPY package.json pnpm-lock.yaml ./

RUN pnpm install --frozen-lockfile

# -----------------------------------------------------------------------------
# Build the production bundle
# -----------------------------------------------------------------------------
FROM deps AS build

COPY . .

RUN pnpm build

# -----------------------------------------------------------------------------
# Runtime image containing the compiled assets and production dependencies
# -----------------------------------------------------------------------------
FROM base AS runtime

ENV NODE_ENV=production \
    START_CMD="pnpm exec vite preview --host 0.0.0.0 --port 5173 --config /app/vite.preview.config.ts"

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package.json ./package.json
COPY --from=build /app/dist ./dist
COPY /vite.config.ts /app/vite.config.ts
COPY /vite.preview.config.ts /app/vite.preview.config.ts

# Use sh -lc to allow START_CMD to be a full shell pipeline if needed.
CMD ["/bin/sh", "-lc", "PORT=${PORT:-5173}; exec sh -lc \"${START_CMD:-pnpm exec vite preview --host 0.0.0.0 --port $PORT --config /app/vite.preview.config.ts}\""]
