# Multi-stage Dockerfile: builds the frontend (Vite) and the API server (Express)
# Produces two images via build targets: `api` and `web`.

# ---------- Base ----------
FROM node:24-alpine AS base
RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app

# ---------- Dependencies ----------
FROM base AS deps
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml .npmrc tsconfig.base.json tsconfig.json ./
COPY artifacts/api-server/package.json ./artifacts/api-server/
COPY artifacts/sar-detection/package.json ./artifacts/sar-detection/
COPY lib/db/package.json ./lib/db/
COPY lib/api-spec/package.json ./lib/api-spec/
COPY lib/api-zod/package.json ./lib/api-zod/
COPY lib/api-client-react/package.json ./lib/api-client-react/
RUN pnpm install --frozen-lockfile

# ---------- Build ----------
FROM deps AS build
COPY . .
ENV PORT=3000
ENV BASE_PATH=/
RUN pnpm --filter @workspace/api-server run build \
 && pnpm --filter @workspace/sar-detection run build

# ---------- API runtime ----------
FROM node:24-alpine AS api
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@latest --activate
COPY --from=build /app/package.json /app/pnpm-workspace.yaml /app/pnpm-lock.yaml /app/.npmrc ./
COPY --from=build /app/artifacts/api-server ./artifacts/api-server
COPY --from=build /app/lib ./lib
COPY --from=build /app/node_modules ./node_modules
ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000
CMD ["node", "--enable-source-maps", "artifacts/api-server/dist/index.mjs"]

# ---------- Web (static) ----------
FROM nginx:alpine AS web
COPY --from=build /app/artifacts/sar-detection/dist/public /usr/share/nginx/html
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
