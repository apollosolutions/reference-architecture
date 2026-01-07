import {
  ConsoleSpanExporter,
  SpanExporter,
} from '@opentelemetry/sdk-trace-node';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import {
  PeriodicExportingMetricReader,
  ConsoleMetricExporter,
} from '@opentelemetry/sdk-metrics';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import {
  OTLPMetricExporter,
} from '@opentelemetry/exporter-metrics-otlp-http';
import { ReadableSpan } from '@opentelemetry/sdk-trace-base';
import { name } from './lib';
import * as env from 'env-var';

const url = env.get('OTEL_HTTP_ENDPOINT').asString()?.trim();

// OTLP exporter can accept either:
// - Base URL (will append /v1/traces automatically)
// - Full URL with /v1/traces (will use as-is)
// Use the URL as-is since the environment variable already includes /v1/traces
let otlpUrl = url;
// If URL doesn't end with /v1/traces, ensure it's a base URL (exporter will append)
if (url && !url.endsWith('/v1/traces')) {
  // Remove trailing slash if present
  otlpUrl = url.replace(/\/$/, '');
}

// Wrapper to log trace export failures
class LoggingSpanExporter implements SpanExporter {
  private exporter: SpanExporter;

  constructor(exporter: SpanExporter) {
    this.exporter = exporter;
  }

  export(spans: ReadableSpan[], resultCallback: (result: { code: number; error?: Error }) => void): void {
    this.exporter.export(spans, (result) => {
      if (result.code !== 0) {
        console.error(`[${name}] Failed to export ${spans.length} span(s):`, {
          error: result.error?.message || result.error,
          code: result.code,
        });
      }
      resultCallback(result);
    });
  }

  shutdown(): Promise<void> {
    return this.exporter.shutdown();
  }
}

// Create trace exporter with logging wrapper
let traceExporter: SpanExporter;
if (otlpUrl) {
  const otlpExporter = new OTLPTraceExporter({ url: otlpUrl });
  traceExporter = new LoggingSpanExporter(otlpExporter);
} else {
  traceExporter = new ConsoleSpanExporter();
  console.warn(`[${name}] OTEL_HTTP_ENDPOINT not set, using ConsoleSpanExporter (traces will only appear in logs)`);
}

const sdk = new NodeSDK({
  serviceName: name,
  traceExporter,
  metricReader: new PeriodicExportingMetricReader({
    exporter: otlpUrl ? new OTLPMetricExporter({ url: otlpUrl }) : new ConsoleMetricExporter(),
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
