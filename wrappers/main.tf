module "wrapper" {
  source = "../"

  for_each = var.items

  create_namespace_export_sink = try(each.value.create_namespace_export_sink, var.defaults.create_namespace_export_sink, true)
  enabled                      = try(each.value.enabled, var.defaults.enabled, null)
  gcs                          = try(each.value.gcs, var.defaults.gcs, null)
  namespace                    = try(each.value.namespace, var.defaults.namespace, "")
  s3                           = try(each.value.s3, var.defaults.s3, null)
  sink_name                    = try(each.value.sink_name, var.defaults.sink_name, "")
  timeouts                     = try(each.value.timeouts, var.defaults.timeouts, {})
}
