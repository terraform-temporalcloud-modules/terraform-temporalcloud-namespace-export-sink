provider "temporalcloud" {
  # Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

################################################################################
# Local regression coverage
#
# The examples/ directories source the PUBLISHED module so they are copy-pasteable
# for consumers. That means they validate the last release, not the code in this
# repo — a renamed or removed variable would slip through CI unnoticed.
#
# This directory closes that gap: it sources the module by relative path and
# passes EVERY input, so `terraform validate` fails here the moment the variable
# surface changes incompatibly. CI picks it up automatically because it contains a
# versions.tf with required_version.
#
# When you add a variable to the root module, add it here in the same PR. Adding
# it to examples/ has to wait until the next release publishes it.
################################################################################

# Every input the module accepts, with the S3 destination.
module "all_inputs_s3" {
  source = "../../"

  create_namespace_export_sink = true

  namespace = "yulei-tflocal-test.a1b2c"
  sink_name = "yulei-tflocal-s3"
  enabled   = true

  s3 = {
    aws_account_id = "123456789012"
    bucket_name    = "yulei-tflocal-export"
    region         = "us-east-1"
    role_name      = "temporal-cloud-export"
    kms_arn        = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  }

  timeouts = {
    create = "10m"
    delete = "10m"
  }
}

# The GCS destination, identified by service account email. Exactly one
# destination may be set per sink, so the two branches need separate calls.
module "all_inputs_gcs" {
  source = "../../"

  namespace = "yulei-tflocal-test.a1b2c"
  sink_name = "yulei-tflocal-gcs"
  enabled   = false

  gcs = {
    bucket_name           = "yulei-tflocal-export"
    region                = "us-central1"
    service_account_email = "temporal-cloud-export@yulei-tflocal.iam.gserviceaccount.com"
  }
}

# The other way of identifying the GCS service account: ID plus project, with no
# email. Both forms are accepted, so both are covered here.
module "gcs_service_account_id" {
  source = "../../"

  namespace = "yulei-tflocal-test.a1b2c"
  sink_name = "yulei-tflocal-gcs-sa-id"

  gcs = {
    bucket_name        = "yulei-tflocal-export"
    region             = "us-central1"
    gcp_project_id     = "yulei-tflocal"
    service_account_id = "temporal-cloud-export"
  }
}

# The create flag off: proves the module produces no resources and that every
# output still evaluates via its try() fallback.
module "disabled" {
  source = "../../"

  create_namespace_export_sink = false
}

# Minimum viable call: a namespace, a sink name and one destination.
module "minimal" {
  source = "../../"

  namespace = "yulei-tflocal-minimal.a1b2c"
  sink_name = "yulei-tflocal-minimal"

  s3 = {
    aws_account_id = "123456789012"
    bucket_name    = "yulei-tflocal-export"
    region         = "us-east-1"
    role_name      = "temporal-cloud-export"
  }
}

# The wrapper, exercised through the local path as well.
module "wrapper" {
  source = "../../wrappers"

  defaults = {
    namespace = "yulei-tflocal-test.a1b2c"
    enabled   = true
  }

  items = {
    orders = {
      sink_name = "yulei-tflocal-orders"

      s3 = {
        aws_account_id = "123456789012"
        bucket_name    = "yulei-tflocal-export-orders"
        region         = "us-east-1"
        role_name      = "temporal-cloud-export"
      }
    }

    audit = {
      sink_name = "yulei-tflocal-audit"
      # Overrides the shared default above.
      enabled = false

      gcs = {
        bucket_name           = "yulei-tflocal-export-audit"
        region                = "us-central1"
        service_account_email = "temporal-cloud-export@yulei-tflocal.iam.gserviceaccount.com"
      }
    }
  }
}
