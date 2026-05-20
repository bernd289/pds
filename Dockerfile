FROM node:24-trixie-slim@sha256:291be77873bc04731968cacf82f0fcef17cee8cf200c6b6951e2bcab41560eb7 AS build

WORKDIR /app
COPY ./service ./

RUN npm i -g corepack && \
    corepack prepare pnpm@11 --activate && \
    npm i -g sfw && \
    sfw pnpm install --production --frozen-lockfile

FROM gcr.io/distroless/nodejs24-debian13:latest@sha256:e70510b44870c5686983f2b11f22b884f2dfacf86aea69b6b0edb2ccb3f237f4 AS run

WORKDIR /app
COPY --chown=1000:1000 --from=build /app /app
USER 1000:1000

EXPOSE 3000

ENV NODE_ENV=production \
    PDS_PORT=3000

HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 \
    CMD ["/nodejs/bin/node", "-e", "require('http').get('http://localhost:3000/xrpc/_health', (res) => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]

CMD ["index.js"]

LABEL org.opencontainers.image.source=https://github.com/bernd289/pds \
      org.opencontainers.image.description="AT Protocol PDS" \
      org.opencontainers.image.licenses=MIT
