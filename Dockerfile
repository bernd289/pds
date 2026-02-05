FROM dhi.io/node:24-alpine3.23-sfw-dev@sha256:1fcd67842c084b0aa03fff8c0e0147a85fdd793dc39076759a8eb8b33be9107f AS build

# Move files into the image and install
WORKDIR /app
COPY ./service ./

RUN sfw pnpm install --production --frozen-lockfile

# Uses assets from build stage to reduce build size
FROM dhi.io/node:24-alpine3.23@sha256:fb4c555fa9c49cb8c7b4eb1950cec4f93a11f409781a39d8883504e53d0a8c49 AS run

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
