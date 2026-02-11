FROM dhi.io/node:24-alpine3.23-sfw-dev@sha256:47c31e716645b0be2bf617931c9ebbf94937968c35bd0f2d5685d443303ba853 AS build

WORKDIR /app
COPY ./service ./

RUN sfw pnpm install --production --frozen-lockfile

FROM dhi.io/node:24-alpine3.23@sha256:5184ed6975ac14fd07ddb63c8e2b104208f0c49905b2826e4c41c97407f85445 AS run

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
