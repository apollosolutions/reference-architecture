import express from "express";
import { PROMOTIONS } from "./data";

const app = express();
const PORT = process.env.PORT ?? "4010";

app.use(express.json());

/**
 * GET /api/promotions
 * Returns all active promotions
 */
app.get("/api/promotions", (_req, res) => {
  res.json({ promotions: PROMOTIONS });
});

/**
 * GET /api/promotions/product/:productId
 * Returns promotions that apply to a specific product
 */
app.get("/api/promotions/product/:productId", (req, res) => {
  const { productId } = req.params;
  const promotions = PROMOTIONS.filter((p) =>
    p.productIds.includes(productId)
  );
  res.json({ promotions });
});

/**
 * GET /api/health
 * Health check for Kubernetes probes
 */
app.get("/api/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.listen(Number(PORT), () => {
  console.log(`Promotions API listening on port ${PORT}`);
});
