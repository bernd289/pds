FROM node:24-trixie-slim@sha256:45fbb3ca3b6c7e6646cd2889d0ac7bf314bb180036da792221fc2f48fe4d43fb AS build

WORKDIR /app
COPY ./service ./

RUN npm i -g pnpm@11 && \
    npm i -g sfw && \
    sfw pnpm install --production --frozen-lockfile

FROM gcr.io/distroless/nodejs24-debian13:latest@sha256:10e262383ceb3a2a5f6f5ceaca5ecebe74951eff21868a055589676eec3a8001 AS run

WORKDIR /app
COPY --chown=1000:1000 --from=build /app /app
USER 1000:1000

EXPOSE 3000

ENV NODE_ENV=production \
    PDS_PORT=3000

HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 \
    CMD ["/nodejs/bin/node", "-e", "require('http').get('http://localhost:3000/xrpc/_health', (res) => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]

CMD ["index.ts"]

LABEL org.opencontainers.image.source=https://github.com/bernd289/pds \
      org.opencontainers.image.description="AT Protocol PDS" \
      org.opencontainers.image.licenses=MIT
