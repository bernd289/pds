FROM dhi.io/node:24-debian13-sfw-dev@sha256:ee6c3607a7ddedb46f8550d26bb758f38b83a192e95cb07b889721b2df8d2b6e AS build

WORKDIR /app
COPY ./service ./

RUN pnpm install --production --frozen-lockfile

FROM dhi.io/node:24-debian13@sha256:a709c2333a1f4c3f102692dc9e4108868a8679590c312b5645ad423036ec92b2 AS run

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
