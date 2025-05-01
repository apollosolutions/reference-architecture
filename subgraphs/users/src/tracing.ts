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

const sdk = new NodeSDK({
  serviceName: name,
  traceExporter: url ? new OTLPTraceExporter() : new ConsoleSpanExporter(),
  metricReader: new PeriodicExportingMetricReader({
    exporter: url ? new OTLPMetricExporter() : new ConsoleMetricExporter(),
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

