FROM node:22.21.1-trixie-slim AS build

# Move files into the image and install
WORKDIR /app
COPY ./service ./

RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    corepack enable && \
    corepack pnpm config set store-dir /pnpm/store && \
    corepack pnpm install --production --frozen-lockfile --prefer-offline
    
# Uses assets from build stage to reduce build size
FROM node:22.21.1-trixie-slim AS run

RUN apt update && \
    apt upgrade -y && \
    apt install -y tini && \
    apt clean && \
    groupadd -r pds && \
    useradd -r -g pds -m pds

# Avoid zombie processes, handle signal forwarding
ENTRYPOINT ["tini", "--"]

WORKDIR /app
COPY --chown=pds:pds --from=build /app /app

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
