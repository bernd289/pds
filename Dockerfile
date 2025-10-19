FROM node:22.20.0-alpine3.22 AS build

# Move files into the image and install
WORKDIR /app
COPY ./service ./

RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    corepack enable && \
    corepack pnpm install --production --frozen-lockfile && \
    corepack pnpm cache delete && \
    npm uninstall -g corepack
    
# Uses assets from build stage to reduce build size
FROM node:22.20.0-alpine3.22

RUN apk upgrade --no-cache && \
    apk add --no-cache dumb-init curl && \
    rm -rf /var/cache/apk/*

# Avoid zombie processes, handle signal forwarding
ENTRYPOINT ["dumb-init", "--"]

WORKDIR /app
COPY --from=build /app /app

EXPOSE 3000
ENV PDS_PORT=3000
ENV NODE_ENV=production

CMD ["node", "--enable-source-maps", "index.js"]
HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${PDS_PORT}/xrpc/_health || exit 1

LABEL org.opencontainers.image.source=https://github.com/bernd289/pds
LABEL org.opencontainers.image.description="AT Protocol PDS"
LABEL org.opencontainers.image.licenses=MIT
