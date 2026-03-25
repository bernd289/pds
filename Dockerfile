FROM node:24-trixie@sha256:8bd2aa8811c33803aa1677674e5388a4524e8bf1d286200afefb9a4c9bd473ef AS build

WORKDIR /app
COPY ./service ./

RUN corepack enable && \
    npm i -g sfw && \
    sfw pnpm install --production --frozen-lockfile

FROM gcr.io/distroless/nodejs24-debian13@sha256:ea392bfe90af3b558c7b924647a403c4ac37c7e8e9917a86d0830d99732315e2 AS run

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
