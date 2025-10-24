FROM node:22.21.0-alpine3.22 AS build

# Move files into the image and install
WORKDIR /app
COPY ./service ./

RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    corepack enable && \
    corepack pnpm config set store-dir /pnpm/store && \
    corepack pnpm install --production --frozen-lockfile --prefer-offline
    
# Uses assets from build stage to reduce build size
FROM node:22.21.0-alpine3.22

RUN apk upgrade --no-cache && \
    apk add --no-cache dumb-init && \
    rm -rf /var/cache/apk/*

# Avoid zombie processes, handle signal forwarding
ENTRYPOINT ["dumb-init", "--"]

WORKDIR /app
COPY --from=build /app /app
RUN addgroup -S pds && adduser -S pds -G pds && \
    chown -R pds:pds /app

USER pds

EXPOSE 3000
ENV NODE_ENV=production \
    PDS_PORT=3000 \
    NODE_OPTIONS="--enable-source-maps"

CMD ["node", "index.js"]
HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${PDS_PORT}/xrpc/_health || exit 1

LABEL org.opencontainers.image.source=https://github.com/bernd289/pds
LABEL org.opencontainers.image.description="AT Protocol PDS"
LABEL org.opencontainers.image.licenses=MIT
