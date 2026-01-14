FROM dhi.io/node:22.22.0-alpine3.23 AS build

# Move files into the image and install
WORKDIR /app
COPY ./service ./

RUN npm install -g corepack@latest \
    corepack enable && \
    corepack pnpm install --production --frozen-lockfile
    
# Uses assets from build stage to reduce build size
FROM dhi.io/node:22.22.0-alpine3.23 AS run

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
