provider "temporalcloud" {
  # Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

locals {
  name = "ex-${basename(path.cwd)}"

  # The bucket and the namespace must be in the same region, so both are derived
  # from one value. `region` is the plain AWS ID; Temporal Cloud prefixes its own
  # region IDs with the cloud provider.
  aws_region            = "us-east-1"
  temporal_cloud_region = "aws-us-east-1"
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
# The bucket and IAM role below are NOT created by this configuration. Provision
# them first — see the prerequisites in ../../README.md — or the apply fails
# because Temporal Cloud cannot assume the role and write to the bucket.
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

  s3 = {
    # Your AWS account, not Temporal's. Temporal Cloud assumes `role_name` in it.
    aws_account_id = "123456789012"

    # Must already exist, and must be in the same region as the namespace.
    bucket_name = "acme-temporal-export-${local.name}"
    region      = local.aws_region

    # The role NAME, not its ARN. It is resolved inside `aws_account_id`.
    role_name = "temporal-cloud-export"

    # Optional. Set only when the bucket uses a customer-managed KMS key; the
    # role's policy must then also allow kms:GenerateDataKey on it.
    # kms_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  }

  timeouts = {
    create = "10m"
    delete = "10m"
  }
}
