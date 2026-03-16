FROM dhi.io/node:24-debian13-sfw-dev@sha256:11d24d132863ab312a4c1a65266de99591da3aa173259280194ca8ec0c9b44e1 AS build

WORKDIR /app
COPY ./service ./

RUN pnpm install --production --frozen-lockfile

FROM dhi.io/node:24-debian13@sha256:ed4210054472352fa933c1057fd04ebab26382c6cebb50b772e40b9759a57679 AS run

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
