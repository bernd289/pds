FROM dhi.io/node:26-alpine-sfw-dev@sha256:421f0766daaee3636f9a524dc6423e26d16e14039d6d4e0b732d04ad4d672786 AS build

WORKDIR /app
COPY ./service ./

RUN npm i -g pnpm@11 \
 && sfw pnpm install --prod --frozen-lockfile

FROM dhi.io/node:26-alpine@sha256:019a466db59568d3f50abafaa9020ea6cef74ccd4173c753e8634189c461cfd0 AS run

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
