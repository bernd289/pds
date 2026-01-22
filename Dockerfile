FROM dhi.io/node:22-alpine3.23-sfw-dev@sha256:deffbb511fa73da2db194348ca939f962854b04be8bdaf941e87bf612ffc87c0 AS build

# Move files into the image and install
WORKDIR /app
COPY ./service ./

RUN sfw pnpm install --production --frozen-lockfile

# Uses assets from build stage to reduce build size
FROM dhi.io/node:22-alpine3.23@sha256:a447b0d63019b70aa5bc6a10fc8c6cd70f7974b1c766f35ba7c0273d5415c3df AS run

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
