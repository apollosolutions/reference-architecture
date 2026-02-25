import gql from "graphql-tag";
import { buildSubgraphSchema } from "@apollo/subgraph";
import { ApolloServer, ContextFunction } from "@apollo/server";
import {
  StandaloneServerContextFunctionArgument,
  startStandaloneServer,
} from "@apollo/server/standalone";
import * as jose from 'jose';
import { resolvers } from "./resolvers";
import { DataSourceContext } from "./types/DataSourceContext";

const port = process.env.PORT ?? "4001";
const subgraphName = require("../package.json").name;
const JWKS_URL = process.env.JWKS_URL || "http://graphql.users.svc.cluster.local:4001/.well-known/jwks.json";

let jwksCache: ReturnType<typeof jose.createLocalJWKSet> | null = null;
let jwksCacheTime: number = 0;
const JWKS_CACHE_TTL = 3600000; // 1 hour in milliseconds

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

const context: ContextFunction<
  [StandaloneServerContextFunctionArgument],
  DataSourceContext
> = async ({ req }) => {
  // Log warning if trace context is missing
  if (!req.headers['traceparent']) {
    console.warn(`[${subgraphName}] Incoming request missing traceparent header - will create new root trace`);
  }

  let context: DataSourceContext = { 
    auth: req.headers.authorization,
    headers: req.headers 
  };

  if (req.headers.authorization && req.headers.authorization.split(' ')[0] === 'Bearer') {
    const token = req.headers.authorization.split(' ')[1];
    try {
      const jwks = await getJWKS();
      const { payload } = await jose.jwtVerify(token.trim(), jwks);
      context.user = payload;
    } catch (e) {
      if (e.name === 'JOSEError' || e.name === "JWTExpired") {
        // Return context without user if token is invalid/expired
        return context;
      } else {
        console.error(e);
      }
    }
  }

  return context;
};

async function main() {
  const { readFileSync } = await import("fs");
  let typeDefs = gql(
    readFileSync("schema.graphql", {
      encoding: "utf-8",
    })
  );
  const server = new ApolloServer({
    schema: buildSubgraphSchema({ typeDefs, resolvers }),
  });
  const { url } = await startStandaloneServer(server, {
    context,
    listen: { port: Number.parseInt(port) },
  });

  console.log(`🚀  Subgraph ${subgraphName} ready at ${url}`);

}

main();
