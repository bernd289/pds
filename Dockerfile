FROM dhi.io/node:24-alpine3.23-sfw-dev@sha256:f802d417645e24edfee1e13a471bdc7a75f4ca697149c585220072caafa3df8d AS build

WORKDIR /app
COPY ./service ./

RUN sfw pnpm install --production --frozen-lockfile

FROM dhi.io/node:24-alpine3.23@sha256:b1b28a29b855cff582bd2bf3635f83be9bcaad707f6e6ab02dc136d4728d1b67 AS run

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
