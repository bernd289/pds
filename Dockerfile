FROM node:26-alpine@sha256:bff25b16ab13b4789c8d78489c249239fb74c85319cc90fc6122c40123894f1e AS build

WORKDIR /app
COPY ./service ./

RUN wget -O /usr/local/bin/sfw \
      https://github.com/SocketDev/sfw-free/releases/latest/download/sfw-free-musl-linux-x86_64 \
 && chmod +x /usr/local/bin/sfw \
 && npm i -g pnpm@11 \
 && sfw pnpm install --prod --frozen-lockfile

FROM node:26-alpine@sha256:bff25b16ab13b4789c8d78489c249239fb74c85319cc90fc6122c40123894f1e AS run

WORKDIR /app
COPY --chown=node:node --from=build /app /app
USER node:node

EXPOSE 3000

ENV NODE_ENV=production \
    PDS_PORT=3000

HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 \
    CMD ["node", "-e", "require('http').get('http://localhost:3000/xrpc/_health', (res) => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]

CMD ["node", "index.ts"]

LABEL org.opencontainers.image.source=https://github.com/bernd289/pds \
      org.opencontainers.image.description="AT Protocol PDS" \
      org.opencontainers.image.licenses=MIT
