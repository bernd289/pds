FROM dhi.io/node:24-alpine3.23-sfw-dev@sha256:1d7cb31268922bf55ec2e262905f9c9c300bbdd2b7cbb23d20497420f82603aa AS build

WORKDIR /app
COPY ./service ./

RUN corepack enable && \
    sfw pnpm install --production --frozen-lockfile

FROM dhi.io/node:24-alpine3.23@sha256:42bc474bf95f56c62205c8bafe51633e58a9dad67e598a6326cc1458ff3b5b4b AS run

WORKDIR /app
COPY --chown=node:node --from=build /app /app
USER node

EXPOSE 3000

ENV NODE_ENV=production \
    PDS_PORT=3000

HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 \
    CMD ["node", "-e", "require('http').get('http://localhost:3000/xrpc/_health', (res) => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]

CMD ["node", "index.js"]

LABEL org.opencontainers.image.source=https://github.com/bernd289/pds \
      org.opencontainers.image.description="AT Protocol PDS" \
      org.opencontainers.image.licenses=MIT
