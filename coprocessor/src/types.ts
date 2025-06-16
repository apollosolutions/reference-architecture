import { Request } from "express";

export enum CoprocessorStage {
  ROUTER_REQUEST = "RouterRequest",
  ROUTER_RESPONSE = "RouterResponse",
  SUPERGRAPH_REQUEST = "SupergraphRequest",
  SUPERGRAPH_RESPONSE = "SupergraphResponse",
  EXECUTION_REQUEST = "ExecutionRequest",
  EXECUTION_RESPONSE = "ExecutionResponse",
  SUBGRAPH_REQUEST = "SubgraphRequest",
  SUBGRAPH_RESPONSE = "SubgraphResponse",
}

// Coprocessor request body based on configuration in the router.yaml
// see examples https://www.apollographql.com/docs/graphos/routing/customization/coprocessor#example-requests-by-stage
export type CoprocessorRequestBody = {
  version: number;
  stage: CoprocessorStage;
  control: string;
  headers: { [key: string]: string[] };
};

export interface CoprocessorRequest extends Omit<Request, "body"> {
  body: CoprocessorRequestBody;
}
