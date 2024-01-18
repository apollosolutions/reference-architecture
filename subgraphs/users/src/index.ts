import { ApolloServer, ContextFunction } from "@apollo/server";
import { expressMiddleware } from '@apollo/server/express4';
import express from 'express';
import http from 'http';
import {
  StandaloneServerContextFunctionArgument,
  startStandaloneServer,
} from "@apollo/server/standalone";
import * as jose from 'jose'
import cors from 'cors'
import { readFileSync } from "fs";
import gql from "graphql-tag";
import { buildSubgraphSchema } from "@apollo/subgraph";
import { resolvers } from "./resolvers";
import { DataSourceContext } from "./types/DataSourceContext";

const app = express();
const port = process.env.PORT ?? "4001";
const subgraphName = require("../package.json").name;

// For demo purposes, we are hosting the JWKS endpoint 
const jwks = readFileSync("./keys/jwks.json", "utf-8");
const joseJWKS = jose.createLocalJWKSet(JSON.parse(jwks));

const context: ContextFunction<
  [StandaloneServerContextFunctionArgument],
  DataSourceContext
> = async ({ req }) => {
  let context: DataSourceContext = { headers: req.headers }
  if (req.headers.authorization && req.headers.authorization.split(' ')[0] === 'Bearer') {
    const token = req.headers.authorization.split(' ')[1];
    try {
      const { payload } = await jose.jwtVerify(token.trim(), joseJWKS)
      context.user = payload
    } catch (e) {
      if (e.name === 'JOSEError' || e.name === "JWTExpired") {
        return context;
      } else {
        console.error(e)
      }
    }
  }
  return context
};

async function main() {
  const httpServer = http.createServer(app);
  let typeDefs = gql(
    readFileSync("schema.graphql", {
      encoding: "utf-8",
    })
  );
  const server = new ApolloServer({
    schema: buildSubgraphSchema({ typeDefs, resolvers }),
  });
  await server.start();

  // Public key endpoint
  app.get('/.well-known/jwks.json', (req, res) => {
    res.json(JSON.parse(jwks));
  })

  app.use(
    '/',
    cors(),
    express.json(),
    expressMiddleware(server, { context }),
  );

  await new Promise<void>((resolve) => httpServer.listen({ port }, () => resolve()));

  console.log(`🚀  Subgraph ${subgraphName} ready at http://localhost:${port}/`);
}

main();
