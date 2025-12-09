import { WebTracerProvider } from '@opentelemetry/sdk-trace-web';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { FetchInstrumentation } from '@opentelemetry/instrumentation-fetch';
import { ZoneContextManager } from '@opentelemetry/context-zone';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { registerInstrumentations } from '@opentelemetry/instrumentation';

// Get collector endpoint from environment variable, default to localhost for port-forward
const collectorUrl = import.meta.env.VITE_OTEL_COLLECTOR_URL || 'http://localhost:4318';

// Build OTLP URL - ensure it includes /v1/traces
// Remove trailing slash if present
let baseUrl = collectorUrl.trim().replace(/\/$/, '');
// Explicitly append /v1/traces if not already present
let otlpUrl = baseUrl;
if (!otlpUrl.endsWith('/v1/traces')) {
  otlpUrl = `${baseUrl}/v1/traces`;
}

const traceExporter = new OTLPTraceExporter({
  url: otlpUrl, // Full URL with /v1/traces path
});

// Initialize the provider with span processor in constructor
// Note: addSpanProcessor is deprecated, use spanProcessors option instead
const provider = new WebTracerProvider({
  spanProcessors: [new BatchSpanProcessor(traceExporter)],
});

// Register the provider
provider.register({
  contextManager: new ZoneContextManager(),
});

// Register fetch instrumentation to automatically instrument fetch requests
registerInstrumentations({
  instrumentations: [
    new FetchInstrumentation({
      // Propagate trace context in fetch requests (including GraphQL)
      propagateTraceHeaderCorsUrls: [
        new RegExp('.*'), // Allow all URLs for CORS trace propagation
      ],
    }),
  ],
});

console.debug('[tracing] OpenTelemetry browser SDK initialized', {
  collectorUrl: otlpUrl,
  serviceName: 'retail-website',
});

export { provider };
