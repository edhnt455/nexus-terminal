FROM node:20 AS builder

WORKDIR /app

COPY package.json package-lock.json ./
COPY patches ./patches
COPY packages/backend/package.json ./packages/backend/
COPY packages/frontend/package.json ./packages/frontend/
COPY packages/remote-gateway/package.json ./packages/remote-gateway/

RUN npm install

COPY packages/backend/src ./packages/backend/src
COPY packages/backend/tsconfig.json ./packages/backend/
COPY packages/backend/html-presets ./packages/backend/html-presets

COPY packages/frontend/src ./packages/frontend/src
COPY packages/frontend/index.html ./packages/frontend/
COPY packages/frontend/tsconfig.json ./packages/frontend/
COPY packages/frontend/vite.config.ts ./packages/frontend/
COPY packages/frontend/public ./packages/frontend/public/

COPY packages/remote-gateway/src ./packages/remote-gateway/src
COPY packages/remote-gateway/tsconfig.json ./packages/remote-gateway/
COPY packages/remote-gateway/guacamole-lite.d.ts ./packages/remote-gateway/

RUN npm run build --workspace=@nexus-terminal/backend
RUN npm run build --workspace=@nexus-terminal/frontend
RUN npm run build --workspace=@nexus-terminal/remote-gateway
RUN npm prune --omit=dev \
    && if [ -d packages/backend/node_modules ]; then cp -a packages/backend/node_modules/. node_modules/; fi \
    && if [ -d packages/remote-gateway/node_modules ]; then cp -a packages/remote-gateway/node_modules/. node_modules/; fi

FROM node:20-bookworm-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        dumb-init \
        gettext-base \
        nginx \
        supervisor \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/default.conf \
    && mkdir -p /app/data /run/nginx /var/log/supervisor

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json

COPY --from=builder /app/packages/backend/dist ./dist
COPY --from=builder /app/packages/backend/src/locales ./dist/locales
COPY --from=builder /app/packages/backend/html-presets ./html-presets
COPY --from=builder /app/packages/backend/package.json ./packages/backend/package.json

COPY --from=builder /app/packages/remote-gateway/dist ./remote-gateway/dist
COPY --from=builder /app/packages/remote-gateway/package.json ./remote-gateway/package.json

COPY --from=builder /app/packages/frontend/dist /usr/share/nginx/html

COPY docker/nginx.app.conf.template /etc/nginx/templates/nexus-terminal.conf.template
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/entrypoint.sh /usr/local/bin/nexus-terminal-entrypoint.sh

RUN chmod +x /usr/local/bin/nexus-terminal-entrypoint.sh

ENV NODE_ENV=production \
    APP_HTTP_PORT=18111 \
    BACKEND_PORT=18112 \
    DEPLOYMENT_MODE=docker \
    REMOTE_GATEWAY_API_PORT=18113 \
    REMOTE_GATEWAY_WS_PORT=18114 \
    REMOTE_GATEWAY_API_BASE_DOCKER=http://127.0.0.1:18113 \
    REMOTE_GATEWAY_WS_URL_DOCKER=ws://127.0.0.1:18114 \
    GUACD_HOST=127.0.0.1 \
    GUACD_PORT=18115 \
    FRONTEND_URL=http://localhost:18111 \
    MAIN_BACKEND_URL=http://127.0.0.1:18112

EXPOSE 18111 18112 18113 18114

ENTRYPOINT ["dumb-init", "--", "/usr/local/bin/nexus-terminal-entrypoint.sh"]
