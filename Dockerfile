FROM dhi.io/node:26-alpine-sfw-dev@sha256:3f8427985c08df8ddad404e7f24678c03b9a00f38e959ad86d1d457ac4770e29 AS build

WORKDIR /app
COPY ./service ./

RUN npm i -g pnpm@11 \
 && sfw pnpm install --prod --frozen-lockfile

FROM dhi.io/node:26-alpine@sha256:c46d92ba5c7fb4b64e50a43e1a77ed009bce7db1de39397123e2df3ededed04d AS run

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
