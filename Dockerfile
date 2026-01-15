FROM dhi.io/node:22-alpine3.23-sfw-dev@sha256:bbfb299f30cb7099c97a05a3a37447a2b775da58757cbd0cc8eb1b3a55da9257 AS build

# Move files into the image and install
WORKDIR /app
COPY ./service ./

RUN sfw pnpm install --production --frozen-lockfile

# Uses assets from build stage to reduce build size
FROM dhi.io/node:22-alpine3.23@sha256:01f8ceb2bc46d59094b3a4fc18e1f945c76a13e9efe9d1160dfb0884804739f0 AS run

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
