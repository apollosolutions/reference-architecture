import { readFileSync } from "fs";
import gql from "graphql-tag";
import { buildSubgraphSchema } from "@apollo/subgraph";
import { ApolloServer, ContextFunction } from "@apollo/server";
import {
  StandaloneServerContextFunctionArgument,
  startStandaloneServer,
} from "@apollo/server/standalone";
import { resolvers } from "./resolvers";
import { DataSourceContext } from "./types/DataSourceContext";

const port = process.env.PORT ?? "4001";
const subgraphName = require("../package.json").name;

const context: ContextFunction<
  [StandaloneServerContextFunctionArgument],
  DataSourceContext
> = async ({ req }) => {
  // Log warning if trace context is missing
  if (!req.headers['traceparent']) {
    console.warn(`[${subgraphName}] Incoming request missing traceparent header - will create new root trace`);
  }

  return {
    auth: req.headers.authorization,
  };
};

async function main() {
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
