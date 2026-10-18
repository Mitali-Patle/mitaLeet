# Production image for the mitaLeet API.
#   docker build -t mitaleet-server apps/server
#   docker run --env-file apps/server/.env -p 3000:3000 mitaleet-server

# ── build: full deps, compile TypeScript, generate Prisma client ──────────────
FROM node:20-bookworm-slim AS build
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends openssl \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package.json package-lock.json ./
COPY prisma ./prisma
RUN npm ci
COPY tsconfig.json tsconfig.build.json nest-cli.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

# ── runtime: production deps + compiled output only, non-root ─────────────────
FROM node:20-bookworm-slim
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends openssl \
  && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --from=build --chown=node:node /app/prisma ./prisma
COPY --chown=node:node package.json ./
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
# Apply pending migrations (advisory-locked, safe with several instances), then start.
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main"]
