FROM dhi.io/node:22-alpine3.23-dev@sha256:3f8fe22ab83f13a31beee72906f10e8baa03308aaa3d9e2fb1d10e7de6f5f257 AS build

# Move files into the image and install
WORKDIR /app
COPY ./service ./

RUN corepack enable && \
    corepack pnpm install --production --frozen-lockfile

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
    CMD wget --no-verbose --tries=1 --spider http://localhost:${PDS_PORT}/xrpc/_health || exit 1

LABEL org.opencontainers.image.source=https://github.com/bernd289/pds
LABEL org.opencontainers.image.description="AT Protocol PDS"
LABEL org.opencontainers.image.licenses=MIT
