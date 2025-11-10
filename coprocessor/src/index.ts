import express from "express";
import { CoprocessorRequest, CoprocessorStage } from "./types";
import * as jose from 'jose';

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
 * Validates JWT authentication for RouterRequest stage
 * Adds a "source" header to SubgraphRequest stage
 *
 * @param req - The request object
 * @param res - The response object
 */
async function handleCoprocessorRequest(
  req: CoprocessorRequest,
  res: express.Response
): Promise<void> {
  const payload = req.body;

  // Handle RouterRequest stage - validate authentication
  if (payload.stage === CoprocessorStage.ROUTER_REQUEST) {
    const authHeader = payload.headers.authorization?.[0];
    const isValid = await validateToken(authHeader);

    if (!isValid) {
      // Return 401 Unauthorized if token is invalid or missing
      res.json({
        ...payload,
        control: {
          break: 401,
        },
      });
      return;
    }

    // Token is valid, continue with the request
    res.json({
      ...payload,
      control: "continue",
    });
    return;
  }

  // Handle SubgraphRequest stage - add source header
  if (payload.stage === CoprocessorStage.SUBGRAPH_REQUEST) {
    payload.headers["source"] = ["coprocessor"];
    res.json(payload);
    return;
  }

  // For all other stages, pass through unchanged
  res.json(payload);
}

const port = process.env.PORT || 8081;
const app = express();
app.use(express.json());
app.post("/", async (req, res) => {
  try {
    await handleCoprocessorRequest(req as CoprocessorRequest, res);
  } catch (error) {
    console.error("Error handling coprocessor request:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});
app.listen(port, () => {
  console.log(`🚀 Coprocessor running on port ${port}`);
  console.log(`JWKS URL: ${JWKS_URL}`);
});
