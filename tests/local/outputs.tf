# Referencing every output forces Terraform to evaluate each one, so a broken
# output expression fails validation here rather than in a consumer's plan.

output "all_inputs_s3" {
  description = "Every output of the fully configured S3 module instance"
  value = {
    namespace_export_sink_id        = module.all_inputs_s3.namespace_export_sink_id
    namespace_export_sink_name      = module.all_inputs_s3.namespace_export_sink_name
    namespace_export_sink_namespace = module.all_inputs_s3.namespace_export_sink_namespace
    namespace_export_sink_enabled   = module.all_inputs_s3.namespace_export_sink_enabled
    namespace_export_sink_s3        = module.all_inputs_s3.namespace_export_sink_s3
    namespace_export_sink_gcs       = module.all_inputs_s3.namespace_export_sink_gcs
  }
}

output "all_inputs_gcs" {
  description = "Every output of the fully configured GCS module instance"
  value = {
    namespace_export_sink_id        = module.all_inputs_gcs.namespace_export_sink_id
    namespace_export_sink_name      = module.all_inputs_gcs.namespace_export_sink_name
    namespace_export_sink_namespace = module.all_inputs_gcs.namespace_export_sink_namespace
    namespace_export_sink_enabled   = module.all_inputs_gcs.namespace_export_sink_enabled
    namespace_export_sink_s3        = module.all_inputs_gcs.namespace_export_sink_s3
    namespace_export_sink_gcs       = module.all_inputs_gcs.namespace_export_sink_gcs
  }
}

output "gcs_service_account_id" {
  description = "The GCS destination identified by service account ID and project rather than email"
  value       = module.gcs_service_account_id.namespace_export_sink_gcs
}

output "disabled" {
  description = "Outputs when create_namespace_export_sink is false — every one must fall back rather than error"
  value = {
    namespace_export_sink_id        = module.disabled.namespace_export_sink_id
    namespace_export_sink_name      = module.disabled.namespace_export_sink_name
    namespace_export_sink_namespace = module.disabled.namespace_export_sink_namespace
    namespace_export_sink_enabled   = module.disabled.namespace_export_sink_enabled
    namespace_export_sink_s3        = module.disabled.namespace_export_sink_s3
    namespace_export_sink_gcs       = module.disabled.namespace_export_sink_gcs
  }
}

output "minimal" {
  description = "Outputs from the minimum viable module call"
  value       = module.minimal.namespace_export_sink_id
}

output "wrapper" {
  description = "Wrapper outputs, keyed by item name"
  value       = module.wrapper.wrapper
}
