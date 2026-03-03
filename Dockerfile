FROM dhi.io/node:24-alpine3.23-sfw-dev@sha256:a74bbe1cbef3c086ec95dc15f6b0c10d4bbaf75bc4885b9ef660ab396d7b71f4 AS build

WORKDIR /app
COPY ./service ./

RUN npm install -g pnpm && \
    pnpm install --production --frozen-lockfile

FROM dhi.io/node:24-alpine3.23@sha256:ae7cb02cb03e3d5a9fbdebec225655028ee169bd5262a7d09f62a1f1b5e5507d AS run

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
