FROM node:24-trixie-slim@sha256:735dd688da64d22ebd9dd374b3e7e5a874635668fd2a6ec20ca1f99264294086 AS build

WORKDIR /app
COPY ./service ./

RUN corepack enable && \
    npm i -g sfw && \
    sfw pnpm install --production --frozen-lockfile

FROM gcr.io/distroless/nodejs24-debian13:latest@sha256:482fabdb0f0353417ab878532bb3bf45df925e3741c285a68038fb138b714cba AS run

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
