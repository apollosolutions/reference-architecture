import express from "express";
import { CoprocessorRequest, CoprocessorStage } from "./types";
import * as jose from 'jose';
import { initializeMetrics, getMeter } from "./metrics";

const JWKS_URL = process.env.JWKS_URL || "http://graphql.users.svc.cluster.local:4001/.well-known/jwks.json";
let jwksCache: ReturnType<typeof jose.createLocalJWKSet> | null = null;
let jwksCacheTime: number = 0;
const JWKS_CACHE_TTL = 3600000; // 1 hour in milliseconds

/**
 * Fetches JWKS from the users subgraph service
 */
async function getJWKS(): Promise<ReturnType<typeof jose.createLocalJWKSet>> {
  const now = Date.now();

  // Return cached JWKS if still valid
  if (jwksCache && (now - jwksCacheTime) < JWKS_CACHE_TTL) {
    return jwksCache;
  }

  try {
    const response = await fetch(JWKS_URL);
    if (!response.ok) {
      throw new Error(`Failed to fetch JWKS: ${response.statusText}`);
    }
    const jwks = await response.json();
    jwksCache = jose.createLocalJWKSet(jwks);
    jwksCacheTime = now;
    return jwksCache;
  } catch (error) {
    console.error("Error fetching JWKS:", error);
    // Return cached JWKS if available, even if expired
    if (jwksCache) {
      return jwksCache;
    }
    throw error;
  }
}

/**
 * Validates JWT token from authorization header
 */
async function validateToken(token: string | undefined): Promise<boolean> {
  if (!token) {
    return false;
  }

  // Extract token from "Bearer <token>" format
  const tokenValue = token.startsWith("Bearer ") ? token.substring(7) : token;

  try {
    const jwks = await getJWKS();
    await jose.jwtVerify(tokenValue.trim(), jwks);
    return true;
  } catch (error) {
    console.error("JWT validation error:", error);
    return false;
  }
}

/**
 * Handles a coprocessor request
 * Adds a "source" header to SubgraphRequest stage
 *
 * Note: JWT authentication is handled by the router's built-in authentication plugin.
 * The router automatically validates JWTs and enforces the @authenticated directive.
 * The coprocessor should not block requests at RouterRequest stage.
 *
 * @param req - The request object
 * @param res - The response object
 */
async function handleCoprocessorRequest(
  req: CoprocessorRequest,
  res: express.Response
): Promise<void> {
  const payload = req.body;

  // Handle SubgraphRequest stage - add source header
  if (payload.stage === CoprocessorStage.SUBGRAPH_REQUEST) {
    payload.headers["source"] = ["coprocessor"];
    res.json(payload);
    return;
  }

  // For all other stages, pass through unchanged
  res.json(payload);
}

// Initialize OpenTelemetry metrics
initializeMetrics();
const meter = getMeter();

// Create metrics
const requestCounter = meter.createCounter('coprocessor_requests_total', {
  description: 'Total number of coprocessor requests',
});

const requestDuration = meter.createHistogram('coprocessor_request_duration_seconds', {
  description: 'Duration of coprocessor requests in seconds',
});

const errorCounter = meter.createCounter('coprocessor_errors_total', {
  description: 'Total number of coprocessor errors',
});

const stageCounter = meter.createCounter('coprocessor_stage_requests_total', {
  description: 'Total number of requests per coprocessor stage',
});

const port = process.env.PORT || 8081;
const app = express();
app.use(express.json());
app.post("/", async (req, res) => {
  const startTime = Date.now();
  const request = req as CoprocessorRequest;
  const payload = request.body;
  const stage = payload?.stage || 'unknown';

  try {
    // Record stage
    stageCounter.add(1, { stage });

    await handleCoprocessorRequest(request, res);

    // Record successful request
    requestCounter.add(1, { status: 'success', stage });
    const duration = (Date.now() - startTime) / 1000;
    requestDuration.record(duration, { stage, status: 'success' });
  } catch (error) {
    console.error("Error handling coprocessor request:", error);

    // Record error
    errorCounter.add(1, { stage });
    requestCounter.add(1, { status: 'error', stage });
    const duration = (Date.now() - startTime) / 1000;
    requestDuration.record(duration, { stage, status: 'error' });

    res.status(500).json({ error: "Internal server error" });
  }
});
app.listen(port, () => {
  console.log(`🚀 Coprocessor running on port ${port}`);
  console.log(`JWKS URL: ${JWKS_URL}`);
  console.log(`OTLP Metrics endpoint: ${process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://collector.monitoring.svc.cluster.local:4318'}`);
});
