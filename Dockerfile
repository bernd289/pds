FROM dhi.io/node:24-alpine3.23-sfw-dev@sha256:5391e41e7e96ee218bc7865ed753535f9ba509a7f09aa17518e54c497a450b03 AS build

# Move files into the image and install
WORKDIR /app
COPY ./service ./

RUN apk add --no-cache python3 make g++ && \
    sfw pnpm install --production --frozen-lockfile

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
