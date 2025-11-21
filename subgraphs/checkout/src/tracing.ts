import {
  ConsoleSpanExporter,
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
import { name } from './lib';
import * as env from 'env-var';

const url = env.get('OTEL_HTTP_ENDPOINT').asString()?.trim();

// OTLP exporter expects base URL without /v1/traces suffix
// The exporter will automatically append /v1/traces
const otlpUrl = url ? url.replace(/\/v1\/traces$/, '') : undefined;

const sdk = new NodeSDK({
  serviceName: name,
  traceExporter: otlpUrl ? new OTLPTraceExporter({ url: otlpUrl }) : new ConsoleSpanExporter(),
  metricReader: new PeriodicExportingMetricReader({
    exporter: otlpUrl ? new OTLPMetricExporter({ url: otlpUrl }) : new ConsoleMetricExporter(),
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

