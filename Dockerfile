FROM dhi.io/node:26-alpine-sfw-dev@sha256:28eed6fc07b83d5ef1c4c651b7443d335d83d129d37c746148c55677d59f621b AS build

WORKDIR /app
COPY ./service ./

RUN npm i -g pnpm@11 \
 && sfw pnpm install --prod --frozen-lockfile

FROM dhi.io/node:26-alpine@sha256:b033e5bef71bb768416a7eff6c3008d9fe088a40ec6d601a1cbbe253d5efd2cb AS run

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
