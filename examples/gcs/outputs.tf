output "namespace_id" {
  description = "The fully qualified ID of the namespace being exported"
  value       = module.namespace.namespace_id
}

output "namespace_export_sink_id" {
  description = "The unique identifier of the export sink"
  value       = module.export_sink.namespace_export_sink_id
}

output "namespace_export_sink_enabled" {
  description = "Whether the sink is actively exporting"
  value       = module.export_sink.namespace_export_sink_enabled
}

output "namespace_export_sink_gcs" {
  description = "The resolved Google Cloud Storage destination configuration, including the service account ID and project the provider derived from the email"
  value       = module.export_sink.namespace_export_sink_gcs
}
