import { IncomingHttpHeaders } from "http";
import { JWTPayload } from "jose";

//This interface is used with graphql-codegen to generate types for resolvers context
export interface DataSourceContext {
  auth?: string;
  user?: JWTPayload & AdditionalPayloadDetails
  headers?: IncomingHttpHeaders
}

type AdditionalPayloadDetails = {
  scope?: string
}