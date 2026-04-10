FROM node:24-trixie-slim@sha256:9707cd4542f400df5078df04f9652a272429112f15202d22b5b8bdd148df494f AS build

WORKDIR /app
COPY ./service ./

RUN corepack enable && \
    npm i -g sfw && \
    sfw pnpm install --production --frozen-lockfile

FROM gcr.io/distroless/nodejs24-debian13:latest@sha256:4e4eeb453e123270e6ddf697f3ae3801f1e49fe1264a72b5a44262a2215522f2 AS run

WORKDIR /app
COPY --chown=1000:1000 --from=build /app /app
USER 1000:1000

EXPOSE 3000

ENV NODE_ENV=production \
    PDS_PORT=3000

HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 \
    CMD ["/nodejs/bin/node", "-e", "require('http').get('http://localhost:3000/xrpc/_health', (res) => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]

CMD ["index.js"]

LABEL org.opencontainers.image.source=https://github.com/bernd289/pds
LABEL org.opencontainers.image.description="AT Protocol PDS"
LABEL org.opencontainers.image.licenses=MIT
