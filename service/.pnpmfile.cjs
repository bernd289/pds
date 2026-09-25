module.exports = {
  hooks: {
    readPackage(pkg) {
      if (pkg.name === '@atproto/pds') {
        delete pkg.dependencies?.['@atproto-labs/opentelemetry-node']
        delete pkg.dependencies?.['@opentelemetry/instrumentation-aws-sdk']
        delete pkg.dependencies?.['@opentelemetry/instrumentation-ioredis']
        delete pkg.dependencies?.['opentelemetry-plugin-better-sqlite3']
      }
      return pkg
    }
  }
}
