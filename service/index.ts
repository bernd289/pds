import type { Request, Response } from "express";
import type { AtIdentifierString } from "@atproto/lex";
import { PDS, httpLogger } from "@atproto/pds";

void PDS.run({
  onCreated(pds) {
    pds.app.get("/tls-check", (req, res) => {
      void checkHandleRoute(pds, req, res);
    });
  },
}).catch((err) => {
  // Do not propagate the error to Node's UnhandledRejection handler,
  // so telemetry still has a chance to flush.
  console.error("PDS failed to start:", err);
  process.exitCode = 1;

  // Last-resort exit in case resources were not properly cleaned up.
  setTimeout(() => process.exit(process.exitCode || 1), 5000).unref();
});

async function checkHandleRoute(
  pds: PDS,
  req: Request,
  res: Response,
): Promise<Response> {
  try {
    const { domain } = req.query;

    if (!domain || typeof domain !== "string") {
      return res.status(400).json({
        error: "InvalidRequest",
        message: "bad or missing domain query param",
      });
    }

    if (domain === pds.ctx.cfg.service.hostname) {
      return res.json({ success: true });
    }

    const isHostedHandle =
      pds.ctx.cfg.identity.serviceHandleDomains.find((availableDomain) =>
        domain.endsWith(availableDomain),
      );

    if (!isHostedHandle) {
      return res.status(400).json({
        error: "InvalidRequest",
        message: "handles are not provided on this domain",
      });
    }

    const account = await pds.ctx.accountManager.getAccount(
      domain as AtIdentifierString,
    );

    if (!account) {
      return res.status(404).json({
        error: "NotFound",
        message: "handle not found for this domain",
      });
    }

    return res.json({ success: true });
  } catch (err) {
    httpLogger.error({ err }, "check handle failed");

    return res.status(500).json({
      error: "InternalServerError",
      message: "Internal Server Error",
    });
  }
}
