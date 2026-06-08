# Apollo Router on GCP Cloud Run

> Deploying GraphOS Router as a Cloud Run service — config that works, and the constraints that bite. Tracks [AS-223](https://apollographql.atlassian.net/browse/AS-223).

Cloud Run is a clean target for Router: managed scaling, generous free tier, simple secret injection, and OIDC-based auth between services. The tricky bits are around HTTP/2 startup probes, the platform-imposed 60 s request timeout, and Cloud Run's "scale to zero" behaviour interacting with WebSocket subscriptions and long-lived OTel exports.

## Service spec

```yaml
# Apply with: gcloud run services replace router.yaml --region us-central1
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: apollo-router
  annotations:
    run.googleapis.com/launch-stage: GA
spec:
  template:
    metadata:
      annotations:
        # Use the second-gen execution environment — it supports HTTP/2,
        # larger memory, and faster cold starts. First-gen will work but
        # without HTTP/2 between Cloud Run and the Router.
        run.googleapis.com/execution-environment: gen2
        # Cap horizontal autoscaling. Adjust based on subgraph capacity,
        # not Router CPU — Router scales sub-linearly with concurrency.
        autoscaling.knative.dev/maxScale: "20"
        run.googleapis.com/cpu-throttling: "false" # keep CPU during idle for keepalives
    spec:
      # Per-instance concurrent in-flight requests. Router is happy at
      # 80–200 depending on operation shape; start at 80 and tune from metrics.
      containerConcurrency: 80
      timeoutSeconds: 60 # Cloud Run hard ceiling unless you opt into 60min preview
      serviceAccountName: apollo-router@PROJECT.iam.gserviceaccount.com
      containers:
        - image: ghcr.io/apollographql/router:v2.10.0
          ports:
            - name: http1 # use h2c if you want HTTP/2 end-to-end
              containerPort: 4000
          env:
            - name: APOLLO_GRAPH_REF
              value: my-graph@main
            - name: APOLLO_ROUTER_LOG
              value: info
            - name: APOLLO_KEY
              valueFrom:
                secretKeyRef:
                  name: apollo-key
                  key: latest
          startupProbe:
            httpGet:
              # Cloud Run cold-starts can take 2-5s while Router fetches its
              # supergraph from Uplink. Probe the health endpoint, NOT 4000.
              path: /health
              port: 8088
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 12 # tolerate up to ~60s cold start
          livenessProbe:
            httpGet:
              path: /health
              port: 8088
            periodSeconds: 30
          resources:
            limits:
              cpu: "2"
              memory: 2Gi
```

The Router's separate health-check port `:8088` is essential here — the default Cloud Run probe assumes the listening port, which for Router is `:4000` for GraphQL traffic. A probe against `:4000/health` returns 404 and Cloud Run will mark the revision dead.

## Constraints you will hit

### Request timeout

Cloud Run's request timeout maxes at **60 minutes** (preview) or **60 seconds** (GA default). Set `timeoutSeconds` explicitly and align Router's `supergraph.defer.deferred_timeout` so deferred fragments don't outlive the Cloud Run request. Subscriptions over plain HTTP/WebSocket can survive up to the request timeout — but Cloud Run will silently drop the connection past it.

### WebSocket subscriptions

Cloud Run does support WebSockets in second-gen. Two caveats:

1. The WebSocket lifetime is capped by `timeoutSeconds`. Long-lived subscriptions need either short request timeouts on the client (and reconnect on close) or Router's [callback subscriptions](https://www.apollographql.com/docs/graphos/routing/operations/subscriptions/multi-cloud-callback-setup) (HTTP polling-based).
2. Cookies-based sticky sessions don't exist on Cloud Run. If your subscription transport needs the same backend across reconnects, use callback mode.

### Cold starts and Uplink

A scale-to-zero revision pays a 2-5 s cold start every time, dominated by:
1. Container pull (cache after first request in a region).
2. Router fetching the supergraph schema from `uplink.api.apollographql.com`.

If 2-5 s is too long, set `minScale: 1` to keep one warm instance. That re-enables billing during idle but eliminates Uplink-related cold start.

### Egress

Cloud Run egress hits the public internet by default. Outbound calls to Uplink and to subgraphs need either:
- **No VPC connector** — works for public subgraphs and Uplink, but bills as managed egress.
- **Direct VPC egress** (gen2) — routes through a VPC, lets you reach Cloud SQL / private subgraphs, doesn't pay managed egress markup.

## Authenticating to private subgraphs

Cloud Run services authenticate to each other with [Google-signed OIDC tokens](https://cloud.google.com/run/docs/authenticating/service-to-service). Router doesn't natively mint these, and **Rhai is the wrong tool here** — the Rhai surface has no outbound HTTP primitive (no `fetch()`/`http_post()`), and `request.subgraph.headers` is only writable from `subgraph_service`, not `supergraph_service`. Use a [coprocessor](https://www.apollographql.com/docs/graphos/routing/customization/coprocessor) at the `SubgraphRequest` stage: have it mint the OIDC token from the Cloud Run metadata server and inject the `Authorization: Bearer …` header before the Router calls the subgraph.

```yaml title="router.yaml — coprocessor wire-up"
coprocessor:
  url: http://127.0.0.1:8080
  subgraph:
    all:
      request:
        headers: true
```

```js title="coprocessor (Node) — issue an OIDC ID token per subgraph and inject it"
import express from "express";

const app = express();
app.use(express.json({ limit: "5mb" }));

// Cache tokens by audience; Cloud Run ID tokens are valid for ~1 hour.
const tokenCache = new Map();
const tokenFor = async (audience) => {
  const cached = tokenCache.get(audience);
  if (cached && cached.expiresAt > Date.now() + 60_000) return cached.token;
  const res = await fetch(
    `http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=${encodeURIComponent(audience)}`,
    { headers: { "Metadata-Flavor": "Google" } },
  );
  if (!res.ok) throw new Error(`metadata server ${res.status}`);
  const token = await res.text();
  tokenCache.set(audience, { token, expiresAt: Date.now() + 55 * 60_000 });
  return token;
};

app.post("/", async (req, res) => {
  const payload = req.body;
  // Audience is the subgraph's Cloud Run URL (https://service-...-run.app).
  const subgraphUrl = payload.context?.entries?.["apollo::subgraph::request_url"];
  if (payload.stage === "SubgraphRequest" && subgraphUrl) {
    const audience = new URL(subgraphUrl).origin;
    const token = await tokenFor(audience);
    payload.headers ??= {};
    payload.headers["authorization"] = [`Bearer ${token}`];
  }
  res.json(payload);
});
app.listen(8080);
```

Run the coprocessor as a sidecar on the same Cloud Run revision so it can reach the metadata server with the Router's service account identity.

## Known issue references

- [`apollographql/router#3517`](https://github.com/apollographql/router/issues/3517) — Cloud Run container startup failure (`/usr/bin/env: 'bash': No such file or directory`). The official Router images are intentionally distroless and ship no shell; do not depend on `bash` in image-entrypoint hooks or Cloud Run launch scripts. Use a Cloud Run job, an init container, or invoke the Router binary directly.

## See also

- [Router self-hosted runtime](https://www.apollographql.com/docs/graphos/routing/self-hosted/containerization/docker)
- [Router health checks](https://www.apollographql.com/docs/graphos/routing/self-hosted/health-checks)
- [Router subscriptions (callback mode)](https://www.apollographql.com/docs/graphos/routing/operations/subscriptions/multi-cloud-callback-setup)
- [Cloud Run timeouts](https://cloud.google.com/run/docs/configuring/request-timeout)
