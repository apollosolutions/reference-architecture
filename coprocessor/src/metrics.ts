import { MeterProvider, PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { Resource } from '@opentelemetry/resources';
import { SEMRESATTRS_SERVICE_NAME } from '@opentelemetry/semantic-conventions';
import { metrics } from '@opentelemetry/api';

/**
 * Initialize OpenTelemetry metrics for the coprocessor
 */
export function initializeMetrics(): void {
  const otlpEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://collector.monitoring.svc.cluster.local:4318';
  const serviceName = process.env.OTEL_SERVICE_NAME || 'coprocessor';

  const resource = new Resource({
    [SEMRESATTRS_SERVICE_NAME]: serviceName,
  });

  // OTLP HTTP exporter expects the base URL, it will append /v1/metrics
  const metricExporter = new OTLPMetricExporter({
    url: otlpEndpoint,
  });

  const meterProvider = new MeterProvider({
    resource,
    readers: [
      new PeriodicExportingMetricReader({
        exporter: metricExporter,
        exportIntervalMillis: 10000, // Export every 10 seconds
      }),
    ],
  });

  metrics.setGlobalMeterProvider(meterProvider);
}

/**
 * Get or create a meter for the coprocessor
 */
export function getMeter() {
  return metrics.getMeter('coprocessor', '1.0.0');
}
