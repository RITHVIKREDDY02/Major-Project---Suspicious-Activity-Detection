# ---- Builder Stage ----
FROM node:20-slim AS builder

RUN npm install -g pnpm@10

WORKDIR /app

COPY . .

RUN pnpm install --frozen-lockfile

ENV BASE_PATH=/
ENV PORT=3000
ENV NODE_ENV=production

RUN pnpm --filter @workspace/sar-detection run build && \
    pnpm --filter @workspace/api-server run build && \
    pnpm store prune --force 2>/dev/null || true

# ---- Runner Stage ----
FROM node:20-slim AS runner

RUN npm install -g pnpm@10

WORKDIR /app

COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY --from=builder /app/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=builder /app/node_modules ./node_modules

COPY --from=builder /app/lib ./lib

COPY --from=builder /app/artifacts/api-server/dist ./artifacts/api-server/dist
COPY --from=builder /app/artifacts/api-server/package.json ./artifacts/api-server/package.json

COPY --from=builder /app/artifacts/sar-detection/dist ./artifacts/sar-detection/dist

COPY entrypoint.sh ./
RUN chmod +x entrypoint.sh

ENV PORT=3000
ENV NODE_ENV=production

EXPOSE 3000

ENTRYPOINT ["./entrypoint.sh"]
