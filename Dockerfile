FROM node:22.15.1-alpine AS build

RUN corepack enable
RUN corepack use pnpm@latest

# Move files into the image and install
WORKDIR /app
COPY ./service ./

RUN pnpm install --production --frozen-lockfile
RUN pnpm cache delete

# Uses assets from build stage to reduce build size
FROM node:22.15.1-alpine

RUN apk upgrade --no-cache
RUN apk add --no-cache dumb-init curl

# Avoid zombie processes, handle signal forwarding
ENTRYPOINT ["dumb-init", "--"]

WORKDIR /app
COPY --from=build /app /app

EXPOSE 3000
ENV PDS_PORT=3000
ENV NODE_ENV=production

CMD ["node", "--enable-source-maps", "index.js"]
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD curl localhost:${PDS_PORT}/xrpc/_health || exit 1

LABEL org.opencontainers.image.source=https://github.com/bernd289/pds
LABEL org.opencontainers.image.description="AT Protocol PDS"
LABEL org.opencontainers.image.licenses=MIT
