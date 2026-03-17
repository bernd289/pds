FROM dhi.io/node:24-alpine3.23-sfw-dev@sha256:ca48c21018a734e60a5758683f0e9a6ca7f973aa322021036166db209fd38e41 AS build

WORKDIR /app
COPY ./service ./

RUN corepack enable && \
    pnpm install --production --frozen-lockfile

FROM dhi.io/node:24-alpine3.23@sha256:01b40b3d18e603a8199b822c0078fee8fb8934f388e90857e464bc7ebd214d11 AS run

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
