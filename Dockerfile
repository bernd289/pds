FROM dhi.io/node:24-debian13-sfw-dev@sha256:e0da6491d5aa3d2945c072d84eca072f5decf6c760800336dfed2685ab0f62de AS build

WORKDIR /app
COPY ./service ./

RUN pnpm install --production --frozen-lockfile

FROM dhi.io/node:24-debian13@sha256:67ecaf83ed7b8554b63af54c760f41daca6f67fb1dec4ba2f3695ccd20269cd6 AS run

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
