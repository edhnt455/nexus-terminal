#!/bin/sh
set -eu

: "${APP_HTTP_PORT:=18111}"
: "${BACKEND_PORT:=3001}"
: "${REMOTE_GATEWAY_API_PORT:=9090}"
: "${REMOTE_GATEWAY_WS_PORT:=8080}"
: "${GUACD_HOST:=127.0.0.1}"
: "${GUACD_PORT:=4822}"
: "${DEPLOYMENT_MODE:=docker}"
: "${REMOTE_GATEWAY_API_BASE_DOCKER:=http://127.0.0.1:${REMOTE_GATEWAY_API_PORT}}"
: "${REMOTE_GATEWAY_WS_URL_DOCKER:=ws://127.0.0.1:${REMOTE_GATEWAY_WS_PORT}}"
: "${FRONTEND_URL:=http://localhost:${APP_HTTP_PORT}}"
: "${MAIN_BACKEND_URL:=http://127.0.0.1:${BACKEND_PORT}}"

export APP_HTTP_PORT
export BACKEND_PORT
export REMOTE_GATEWAY_API_PORT
export REMOTE_GATEWAY_WS_PORT
export GUACD_HOST
export GUACD_PORT
export DEPLOYMENT_MODE
export REMOTE_GATEWAY_API_BASE_DOCKER
export REMOTE_GATEWAY_WS_URL_DOCKER
export FRONTEND_URL
export MAIN_BACKEND_URL

mkdir -p /app/data /run/nginx /var/log/nginx /var/lib/nginx /var/log/supervisor

envsubst '${APP_HTTP_PORT} ${BACKEND_PORT}' \
  < /etc/nginx/templates/nexus-terminal.conf.template \
  > /etc/nginx/conf.d/default.conf

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
