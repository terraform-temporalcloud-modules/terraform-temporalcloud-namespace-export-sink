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

output "namespace_export_sink_s3" {
  description = "The resolved Amazon S3 destination configuration"
  value       = module.export_sink.namespace_export_sink_s3
}
