FROM dhi.io/node:24-alpine3.23-sfw-dev@sha256:59886d4d4932affcf4fac13046044ceb5697985be67f5c2b022a200e38004d47 AS build

# Move files into the image and install
WORKDIR /app
COPY ./service ./

RUN sfw pnpm install --production --frozen-lockfile

# Uses assets from build stage to reduce build size
FROM dhi.io/node:24-alpine3.23@sha256:ceecd317a0886a01f59a07d46f4fc18b4b063be90a9c9d863e8111789fcbba7b AS run

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
