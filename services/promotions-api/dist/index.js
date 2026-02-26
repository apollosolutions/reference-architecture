"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const data_1 = require("./data");
const app = (0, express_1.default)();
const PORT = process.env.PORT ?? "4010";
app.use((0, cors_1.default)());
app.use(express_1.default.json());
/**
 * GET /api/promotions
 * Returns all active promotions
 */
app.get("/api/promotions", (_req, res) => {
    res.json({ promotions: data_1.PROMOTIONS });
});
/**
 * GET /api/promotions/product/:productId
 * Returns promotions that apply to a specific product
 */
app.get("/api/promotions/product/:productId", (req, res) => {
    const { productId } = req.params;
    const promotions = data_1.PROMOTIONS.filter((p) => p.productIds.includes(productId));
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
