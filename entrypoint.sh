#!/bin/sh
set -e

echo "==> Running database migrations..."
pnpm --filter @workspace/db run push-force

echo "==> Starting server on port $PORT..."
exec node --enable-source-maps ./artifacts/api-server/dist/index.mjs
