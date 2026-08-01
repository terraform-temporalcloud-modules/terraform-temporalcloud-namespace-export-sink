// Proves the plan-time rules are enforced.
//
// `command = plan` throughout, so nothing is created and no bucket, role or
// namespace is touched. The provider is still configured, hence
// TEMPORAL_CLOUD_API_KEY.
//
// Every case here is a rejection, and each one is aimed at exactly one rule:
// remove that rule and this file goes red. There is deliberately no "must plan
// cleanly" case. A clean plan would put the provider's own plan-time behaviour
// for a create in play, and no create has ever been run against a real account
// from this repo — see ./README.md. tests/local/ covers the accepting side by
// validating every input.
//
// The exactly-one-destination rule lives in a resource precondition rather than
// a variable validation: a validation cannot reference a second variable below
// Terraform 1.9, and the resource is count-gated so the check is correctly
// skipped when the module is switched off. disabled.tftest.hcl covers that half
// — it must NOT trip this precondition.

provider "temporalcloud" {}

################################################################################
# Destination selection — a resource precondition, so it is reported against the
# resource rather than a variable.
################################################################################

run "rejects_two_destinations" {
  command = plan

  variables {
    namespace = "tftest-export.a1b2c"
    sink_name = "tftest-two-destinations"

    s3 = {
      aws_account_id = "111122223333"
      bucket_name    = "tftest-export"
      region         = "us-east-1"
      role_name      = "temporal-cloud-export"
    }

    gcs = {
      bucket_name           = "tftest-export"
      region                = "us-central1"
      service_account_email = "temporal-export@example-project.iam.gserviceaccount.com"
    }
  }

  expect_failures = [
    temporalcloud_namespace_export_sink.this,
  ]
}

run "rejects_no_destination" {
  command = plan

  variables {
    namespace = "tftest-export.a1b2c"
    sink_name = "tftest-no-destination"
  }

  expect_failures = [
    temporalcloud_namespace_export_sink.this,
  ]
}

################################################################################
# Per-variable rules. Each case trips one rule and leaves the rest satisfied, so
# a failure names the rule that is actually broken.
################################################################################

// The bare namespace name is the likely mistake, and the API's rejection of it
// does not say what the correct form is.
run "rejects_bare_namespace_name" {
  command = plan

  variables {
    namespace = "tftest-export"
    sink_name = "tftest-bare-namespace"

    s3 = {
      aws_account_id = "111122223333"
      bucket_name    = "tftest-export"
      region         = "us-east-1"
      role_name      = "temporal-cloud-export"
    }
  }

  expect_failures = [
    var.namespace,
  ]
}

run "rejects_short_aws_account_id" {
  command = plan

  variables {
    namespace = "tftest-export.a1b2c"
    sink_name = "tftest-short-account-id"

    s3 = {
      aws_account_id = "1234"
      bucket_name    = "tftest-export"
      region         = "us-east-1"
      role_name      = "temporal-cloud-export"
    }
  }

  expect_failures = [
    var.s3,
  ]
}

// role_name is a role NAME. Reaching for the ARN is the natural mistake, and the
// account is already supplied separately.
run "rejects_role_arn_as_role_name" {
  command = plan

  variables {
    namespace = "tftest-export.a1b2c"
    sink_name = "tftest-role-arn"

    s3 = {
      aws_account_id = "111122223333"
      bucket_name    = "tftest-export"
      region         = "us-east-1"
      role_name      = "arn:aws:iam::111122223333:role/temporal-cloud-export"
    }
  }

  expect_failures = [
    var.s3,
  ]
}

run "rejects_non_kms_arn" {
  command = plan

  variables {
    namespace = "tftest-export.a1b2c"
    sink_name = "tftest-non-kms-arn"

    s3 = {
      aws_account_id = "111122223333"
      bucket_name    = "tftest-export"
      region         = "us-east-1"
      role_name      = "temporal-cloud-export"
      kms_arn        = "arn:aws:s3:::tftest-export"
    }
  }

  expect_failures = [
    var.s3,
  ]
}

// All three service account attributes are individually optional, so omitting
// them all looks valid. Temporal Cloud cannot identify the service account.
run "rejects_gcs_without_service_account" {
  command = plan

  variables {
    namespace = "tftest-export.a1b2c"
    sink_name = "tftest-gcs-no-sa"

    gcs = {
      bucket_name = "tftest-export"
      region      = "us-central1"
    }
  }

  expect_failures = [
    var.gcs,
  ]
}

run "rejects_gcs_bare_service_account_name" {
  command = plan

  variables {
    namespace = "tftest-export.a1b2c"
    sink_name = "tftest-gcs-bare-sa"

    gcs = {
      bucket_name           = "tftest-export"
      region                = "us-central1"
      service_account_email = "temporal-export"
    }
  }

  expect_failures = [
    var.gcs,
  ]
}
