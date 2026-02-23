FROM dhi.io/node:24-alpine3.23-sfw-dev@sha256:6e440ce7983780138a90185da8ad99f278ea90a313feaeb7c7716fefe4fcf8c9 AS build

WORKDIR /app
COPY ./service ./

RUN sfw pnpm install --production --frozen-lockfile

FROM dhi.io/node:24-alpine3.23@sha256:c81ed8bde45ba521b82e9667e0a82a56ca00deee15eb81d46a0171f581fd9380 AS run

WORKDIR /app
COPY --chown=node:node --from=build /app /app
USER node

EXPOSE 3000

ENV NODE_ENV=production \
    PDS_PORT=3000

CMD ["node", "index.js"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 \
    CMD ["node", "-e", "require('http').get('http://localhost:3000/xrpc/_health', (res) => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]

LABEL org.opencontainers.image.source=https://github.com/bernd289/pds
LABEL org.opencontainers.image.description="AT Protocol PDS"
LABEL org.opencontainers.image.licenses=MIT
