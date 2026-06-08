# Authenticating Apollo Router on AWS with JWT and SigV4

> Validate inbound JWTs at the Router edge and sign outbound requests to AWS-backed subgraphs with SigV4. Tracks [AS-184](https://apollographql.atlassian.net/browse/AS-184).

This tech note covers two complementary patterns for running GraphOS Router on AWS:

1. **JWT at the edge** — Router validates an inbound JWT (typically from Amazon Cognito, Auth0, Okta, or any OIDC IdP) before any subgraph fetch.
2. **SigV4 to subgraphs** — Router signs outbound subgraph requests with AWS Signature V4 so it can call IAM-protected backends like API Gateway, Lambda Function URLs, AppSync, and App Runner without long-lived secrets.

Both patterns can run independently or together. End-to-end, the inbound JWT proves _who_ the caller is, and SigV4 proves to AWS that _Router_ is the authorized service hop.

## Pattern 1 — Validate inbound JWTs at the Router

The Router's [JWT authentication plugin](https://www.apollographql.com/docs/graphos/routing/security/jwt) validates a `Bearer` token against one or more JWKS endpoints and rejects unauthenticated traffic before composition. With AWS-hosted IdPs the JWKS URL is fully managed for you.

```yaml title="router.yaml"
authentication:
  router:
    jwt:
      jwks:
        # Amazon Cognito user pool — JWKS is published at a stable URL per
        # region+pool. Cognito access tokens use RS256 by default.
        - url: https://cognito-idp.${AWS_REGION}.amazonaws.com/${USER_POOL_ID}/.well-known/jwks.json
          # Optionally pin audiences/issuers to lock the token to this graph.
          audiences: ["graphos-router"]
          issuers:
            - https://cognito-idp.${AWS_REGION}.amazonaws.com/${USER_POOL_ID}

authorization:
  # Reject any operation that hits a field requiring auth without a valid JWT.
  require_authentication: true
  directives:
    enabled: true
```

The plugin populates [request claims](https://www.apollographql.com/docs/graphos/routing/security/jwt#working-with-jwt-claims) (sub, scope, custom Cognito groups) into the supergraph context. From there, the [`@requiresScopes`](https://www.apollographql.com/docs/graphos/routing/security/authorization#requiresscopes) and [`@policy`](https://www.apollographql.com/docs/graphos/routing/security/authorization#policy) directives let you enforce per-field authorization without modifying subgraph code.

### Cognito-specific gotchas

- **Access tokens vs ID tokens** — point Router at access tokens. Cognito ID tokens have `aud` claims that match the client ID, not your graph, and they aren't intended for downstream APIs.
- **Token TTL** — Cognito access tokens default to 60 min; for long subscriptions, refresh client-side rather than extending the JWT lifetime. See the [JWT authentication](https://www.apollographql.com/docs/graphos/routing/security/jwt) reference for the supported claim set.
- **Region awareness** — JWKS URLs are regional. Use the same region as your Cognito user pool, not your Router region, in the JWKS URL.

## Pattern 2 — Sign outbound subgraph requests with SigV4

When a subgraph is an IAM-authenticated AWS service (HTTP API Gateway with IAM auth, Lambda Function URL with `AWS_IAM`, AppSync with `AWS_IAM`, App Runner private services), the Router must sign every subgraph request with [AWS Signature V4](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_aws-signing.html).

The native way to do this in the Router is the [SigV4 subgraph authentication plugin](https://www.apollographql.com/docs/graphos/routing/security/subgraph-authentication) (Router 1.43+, GA in 2.x). It picks up credentials from the standard AWS provider chain — environment variables, IRSA on EKS, ECS task role, or EC2 instance profile.

```yaml title="router.yaml"
authentication:
  subgraph:
    all:
      aws_sig_v4:
        default_chain:
          # Pinning service+region keeps the signature aligned with the target
          # AWS service. Use `execute-api` for API Gateway, `lambda` for
          # Function URLs, `appsync` for AppSync, `apprunner` for App Runner.
          profile_name: default
          region: us-east-1
          service_name: execute-api
          assume_role: # optional cross-account
            role_arn: arn:aws:iam::111122223333:role/RouterSubgraphCaller
            session_name: router-subgraph
    subgraphs:
      # Per-subgraph override when one of them is a non-AWS endpoint.
      legacy_internal:
        aws_sig_v4: null
```

### Wiring credentials in EKS / Fargate

Don't bake long-lived AWS keys into the Router pod spec. Use the native AWS identity primitives instead:

- **EKS**: attach an [IAM role to the Router pod's service account (IRSA)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html); the AWS SDK picks it up via `AWS_WEB_IDENTITY_TOKEN_FILE` + `AWS_ROLE_ARN`.
- **ECS/Fargate**: attach a [task role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html); credentials are exposed via the container metadata endpoint.
- **EC2**: an [instance profile](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html) on the host the Router runs on.

The Router auth plugin uses the default AWS credential chain, so as long as one of the above is in place no further config is needed.

### Verifying the signature

Two quick smoke tests:

1. Hit your subgraph from outside the cluster without signing — it must return `403 Missing Authentication Token` (API Gateway) or `403 Forbidden` (Function URL with IAM). That confirms IAM is enforcing.
2. With Router signing enabled, send a query that fans out to the subgraph and tail `apollo.router` debug logs. The plugin emits a span attribute with the canonical request hash; if requests fail, the AppSync/API Gateway CloudWatch logs will surface the mismatch reason (most commonly clock skew or wrong region).

## Combining the two

```yaml title="router.yaml — JWT in, SigV4 out"
authentication:
  router:
    jwt:
      jwks:
        - url: https://cognito-idp.us-east-1.amazonaws.com/us-east-1_xxx/.well-known/jwks.json
  subgraph:
    all:
      aws_sig_v4:
        default_chain:
          region: us-east-1
          service_name: execute-api

authorization:
  require_authentication: true

headers:
  all:
    request:
      # Don't forward the inbound bearer token to AWS-signed subgraphs — the
      # SigV4 signature is in the request headers we generate, not in
      # Authorization, and forwarding both can fail signature validation.
      - remove:
          named: authorization
```

## Further reading

- [Router JWT authentication](https://www.apollographql.com/docs/graphos/routing/security/jwt)
- [Router subgraph authentication (SigV4)](https://www.apollographql.com/docs/graphos/routing/security/subgraph-authentication)
- [Router authorization directives](https://www.apollographql.com/docs/graphos/routing/security/authorization)
- [IAM authentication for API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/permissions.html)
- [Lambda Function URL IAM auth](https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html)
