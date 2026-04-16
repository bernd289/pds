FROM dhi.io/node:24-alpine3.23-sfw-dev@sha256:8ed1a1c6b79c37d0f566983edd2e14eba81fa2b89d5f99605b63ccdcef4840de AS build

WORKDIR /app
COPY ./service ./

RUN corepack enable && \
    sfw pnpm install --production --frozen-lockfile

FROM dhi.io/node:24-alpine3.23@sha256:52280ec4ad86ef1dbd8bb0999b66c7b309cde16391b4e4ea277505d7ffb71d3d AS run

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
