provider "temporalcloud" {
  # Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

locals {
  name = "ex-${basename(path.cwd)}"

  # The bucket and the namespace must be in the same region, so both are derived
  # from one value. `region` is the plain GCP ID; Temporal Cloud prefixes its own
  # region IDs with the cloud provider.
  gcp_region            = "us-central1"
  temporal_cloud_region = "gcp-us-central1"
}

################################################################################
# The namespace to export from
#
# Created here so the example is self-contained. In practice this is usually an
# existing namespace, in which case pass its ID directly or read it with the
# `temporalcloud_namespace` data source.
################################################################################

module "namespace" {
  source  = "terraform-temporalcloud-modules/namespace/temporalcloud"
  version = "~> 1.0"

  name           = local.name
  regions        = [local.temporal_cloud_region]
  retention_days = 7
  api_key_auth   = true
}

################################################################################
# Export sink
#
# The bucket and service account below are NOT created by this configuration.
# Provision them first — see the prerequisites in ../../README.md — or the apply
# fails because Temporal Cloud cannot impersonate the service account and write
# to the bucket.
################################################################################

module "export_sink" {
  source  = "terraform-temporalcloud-modules/namespace-export-sink/temporalcloud"
  version = "~> 1.0"

  # The fully qualified namespace ID `<namespace>.<account_id>`, not the bare
  # name. Taking it from the module output rather than typing it avoids the most
  # common mistake here.
  namespace = module.namespace.namespace_id

  sink_name = "${local.name}-archive"
  enabled   = true

  gcs = {
    # Must already exist, must be a single-region bucket, and must be in the
    # same region as the namespace.
    bucket_name = "acme-temporal-export-${local.name}"
    region      = local.gcp_region

    # The service account Temporal Cloud impersonates. Giving the email is
    # enough — the provider derives service_account_id and gcp_project_id from
    # it. The alternative is to set those two instead:
    #
    #   service_account_id = "temporal-cloud-export"
    #   gcp_project_id     = "acme-prod"
    service_account_email = "temporal-cloud-export@acme-prod.iam.gserviceaccount.com"
  }

  timeouts = {
    create = "10m"
    delete = "10m"
  }
}
