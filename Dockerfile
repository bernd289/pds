FROM dhi.io/node:26-alpine-sfw-dev@sha256:79d03e33a3a81178ba5a515b82c374fb029b014aa6ffa73bdbf889a19e90194d AS build

WORKDIR /app
COPY ./service ./

RUN npm i -g pnpm@11 \
 && sfw pnpm install --prod --frozen-lockfile

FROM dhi.io/node:26-alpine@sha256:845b5f1d301d6a65252b7f149ec98f225b82100037f3b20567d78c81f40bbdf1 AS run

WORKDIR /app
COPY --chown=node:node --from=build /app /app
USER node:node

EXPOSE 3000

ENV NODE_ENV=production \
    PDS_PORT=3000

HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 \
    CMD ["node", "-e", "require('http').get('http://localhost:3000/xrpc/_health', (res) => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]

CMD ["node", "index.ts"]

LABEL org.opencontainers.image.source=https://github.com/bernd289/pds \
      org.opencontainers.image.description="AT Protocol PDS" \
      org.opencontainers.image.licenses=MIT
