import { WebTracerProvider } from '@opentelemetry/sdk-trace-web';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { FetchInstrumentation } from '@opentelemetry/instrumentation-fetch';
import { ZoneContextManager } from '@opentelemetry/context-zone';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { registerInstrumentations } from '@opentelemetry/instrumentation';
import { SEMRESATTRS_SERVICE_NAME, SEMRESATTRS_SERVICE_VERSION, SEMRESATTRS_SERVICE_NAMESPACE, SEMRESATTRS_DEPLOYMENT_ENVIRONMENT } from '@opentelemetry/semantic-conventions';

// Helper functions to extract browser information
function getBrowserName(): string {
  const ua = navigator.userAgent;
  if (ua.includes('Chrome') && !ua.includes('Edg')) return 'Chrome';
  if (ua.includes('Firefox')) return 'Firefox';
  if (ua.includes('Safari') && !ua.includes('Chrome')) return 'Safari';
  if (ua.includes('Edg')) return 'Edge';
  return 'Unknown';
}

function getBrowserVersion(): string {
  const ua = navigator.userAgent;
  const match = ua.match(/(Chrome|Firefox|Safari|Edg)\/(\d+)/);
  return match ? match[2] : 'Unknown';
}

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

// Service configuration
const SERVICE_NAMESPACE = 'client';
const SERVICE_NAME = 'retail-website';
const SERVICE_VERSION = '1.0.0';
const DEPLOYMENT_ENVIRONMENT = import.meta.env.VITE_ENVIRONMENT || 'development';

// Create exporter with headers that include service information
const traceExporter = new OTLPTraceExporter({
  url: otlpUrl, // Full URL with /v1/traces path
  headers: {
    // Add custom headers if needed
  },
});

// Create resource attributes object
const resourceAttributes = {
  [SEMRESATTRS_SERVICE_NAME]: `${SERVICE_NAMESPACE}/${SERVICE_NAME}`,
  [SEMRESATTRS_SERVICE_VERSION]: SERVICE_VERSION,
  [SEMRESATTRS_SERVICE_NAMESPACE]: SERVICE_NAMESPACE,
  [SEMRESATTRS_DEPLOYMENT_ENVIRONMENT]: DEPLOYMENT_ENVIRONMENT,
  // Additional useful attributes
  'service.instance.id': `${SERVICE_NAMESPACE}/${SERVICE_NAME}`,
  'user_agent.original': navigator.userAgent,
  'browser.name': getBrowserName(),
  'browser.version': getBrowserVersion(),
};

// Initialize the provider with resource attributes
// Note: Using type assertion as browser SDK Resource types may be incomplete
const provider = new WebTracerProvider({
  spanProcessors: [new BatchSpanProcessor(traceExporter)],
  resource: {
    attributes: resourceAttributes,
  } as any,
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
      clearTimingResources: false,
    }),
  ],
});

console.debug('[tracing] OpenTelemetry browser SDK initialized', {
  collectorUrl: otlpUrl,
  serviceName: `${SERVICE_NAMESPACE}/${SERVICE_NAME}`,
  serviceVersion: SERVICE_VERSION,
  environment: DEPLOYMENT_ENVIRONMENT,
});

export { provider };
