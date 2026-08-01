locals {
  create_namespace_export_sink = var.create_namespace_export_sink

  # A sink writes to exactly one destination. Enforced by a resource
  # precondition rather than a `validation` block because the check spans two
  # variables, and validation blocks cannot reference another variable before
  # Terraform 1.9 — below this module's declared floor. Attaching it to the
  # resource also means it is skipped when the module is switched off, which is
  # the desired behaviour.
  destination_count = length([for destination in [var.s3, var.gcs] : destination if destination != null])
}

################################################################################
# Namespace export sink
#
# `s3` and `gcs` are nested attributes in the provider schema rather than
# blocks, so they are assigned straight from their variables and a null value
# omits them. `timeouts` is the only true block, hence the dynamic block below.
#
# The bucket, and the IAM role or service account Temporal Cloud assumes to
# write to it, are created outside this module. See the README for what they
# must look like — an export sink whose destination is not yet reachable fails
# on create.
################################################################################

resource "temporalcloud_namespace_export_sink" "this" {
  count = local.create_namespace_export_sink ? 1 : 0

  namespace = var.namespace
  sink_name = var.sink_name
  enabled   = var.enabled

  s3  = var.s3
  gcs = var.gcs

  dynamic "timeouts" {
    for_each = length([for v in var.timeouts : v if v != null]) > 0 ? [var.timeouts] : []

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
    }
  }

  lifecycle {
    precondition {
      condition     = local.destination_count == 1
      error_message = "Set exactly one destination: either `s3` or `gcs`. Neither was set, or both were."
    }
  }
}
