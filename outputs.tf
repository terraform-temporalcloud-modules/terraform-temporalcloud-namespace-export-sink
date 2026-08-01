################################################################################
# Namespace export sink
#
# Outputs are wrapped in `try()` so they still evaluate to an empty value when
# `create_namespace_export_sink = false` leaves no resource to reference.
################################################################################

output "namespace_export_sink_id" {
  description = "The unique identifier of the export sink"
  value       = try(temporalcloud_namespace_export_sink.this[0].id, "")
}

output "namespace_export_sink_name" {
  description = "The name of the export sink"
  value       = try(temporalcloud_namespace_export_sink.this[0].sink_name, "")
}

output "namespace_export_sink_namespace" {
  description = "The fully qualified ID of the namespace the sink exports from, in the form `<namespace>.<account_id>`"
  value       = try(temporalcloud_namespace_export_sink.this[0].namespace, "")
}

output "namespace_export_sink_enabled" {
  description = "Whether the sink is actively exporting"
  value       = try(temporalcloud_namespace_export_sink.this[0].enabled, false)
}

################################################################################
# Destination
#
# Both are always present; the one that was not configured is null. `gcs`
# reflects the service account attributes the API resolved, which may be fuller
# than what was supplied — supplying only `service_account_email` populates
# `service_account_id` and `gcp_project_id` from it.
################################################################################

output "namespace_export_sink_s3" {
  description = "The resolved Amazon S3 destination configuration. Null when the sink writes to Google Cloud Storage"
  value       = try(temporalcloud_namespace_export_sink.this[0].s3, null)
}

output "namespace_export_sink_gcs" {
  description = "The resolved Google Cloud Storage destination configuration. Null when the sink writes to Amazon S3"
  value       = try(temporalcloud_namespace_export_sink.this[0].gcs, null)
}
