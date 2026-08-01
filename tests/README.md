# Tests

Not usage examples — see [examples/](../examples) for those.

| Path | Runs on | Credentials |
| --- | --- | --- |
| `local/` | every pull request | no |
| `*.tftest.hcl` | on demand, weekly | **yes** |
| `setup/` | helper for `*.tftest.hcl` | no |
| `liveness/` | before the apply tests, from `scripts/check-api.sh` | **yes** |
| `orphan-check/` | see "Leftovers" below — no-op for this module | no |

`local/` passes every module input and references every output, so `terraform
validate` fails there as soon as the variable surface changes.

| File | Covers |
| --- | --- |
| `disabled.tftest.hcl` | `create_namespace_export_sink = false` creates nothing and every output falls back |

## What is not apply-tested, and why

**Creating an export sink is not covered on apply.** It is the whole of this
module's resource surface, so the gap is worth stating plainly rather than
burying: `local/` proves the configuration type-checks, and nothing proves
Temporal Cloud accepts it.

A sink cannot be created against a destination that does not exist. Temporal Cloud
validates the destination while creating the sink — it assumes the IAM role or
impersonates the service account and writes a test object — so there is no
"configure now, wire up later" path and no dry-run flag. Applying against
placeholder values fails, and a test that always fails is worse than none.

Running it needs infrastructure this account does not have. A maintainer would
have to provision, in a cloud account they control:

**For S3**

1. A bucket in the same region as the test namespace. The bucket region and the
   namespace region must match, so the region must also be one the Temporal Cloud
   account is entitled to — `tests/setup/` exposes `available_regions` for that
   check.
2. An IAM role that Temporal Cloud can assume and that can write to the bucket.
   Temporal Cloud publishes a CloudFormation template that creates it; see
   [Exporting Workflow Event History to AWS S3](https://docs.temporal.io/cloud/export/aws-export-s3).
3. Optionally a KMS key, to cover `s3.kms_arn`. The role's policy must allow
   `kms:GenerateDataKey` on it.

**For GCS**

1. A single-region bucket in the same region as the test namespace. Multi-region
   buckets are not supported.
2. A service account in the same project that Temporal Cloud can impersonate and
   that can write to the bucket; see
   [Exporting Workflow Event History to GCS](https://docs.temporal.io/cloud/export/gcp-export-gcs).

**Then, in this repository**

Add a `sink.tftest.hcl` that takes the bucket details from variables rather than
hardcoding them, creates one namespace in the bucket's region, attaches a sink to
it and updates that sink across `run` blocks — one sink, updated, not one per
case. Sketch:

```hcl
provider "temporalcloud" {}

variables {
  // Supplied by the runner; no default, so the file fails fast if unset.
  export_bucket_name  = null
  export_bucket_region = null
  export_aws_account_id = null
  export_role_name    = null
}

run "setup" {
  module {
    source = "./tests/setup"
  }
}

run "create_sink" {
  variables {
    namespace = "<namespace id created by an earlier run block or fixture>"
    sink_name = run.setup.sink_name

    s3 = {
      aws_account_id = var.export_aws_account_id
      bucket_name    = var.export_bucket_name
      region         = var.export_bucket_region
      role_name      = var.export_role_name
    }
  }

  assert {
    condition     = output.namespace_export_sink_name == run.setup.sink_name
    error_message = "sink_name output did not echo the requested name"
  }
}
```

Wire the bucket details in as a `TF_VAR_*` set from repository secrets, and keep
the file out of the default run — `terraform test -filter=` it — until every
account running CI has the infrastructure, or the suite goes red for everyone else.

Two things to expect on that first run, because they are the classes of failure
`terraform validate` cannot see:

- **The region pair.** A bucket region that does not match the namespace region is
  rejected, and the message names the sink rather than the region.
- **The trust policy.** If Temporal Cloud cannot assume the role, creation fails
  with a permissions error rather than a configuration error, and the fix is in
  AWS, not in Terraform.

`enabled = false` and the `timeouts` input can ride along on that test once it
exists; both are covered by `local/` today.

## Running the apply tests

```bash
export TEMPORAL_CLOUD_API_KEY="<key for a scratch account>"
terraform init
terraform test -verbose
```

Point them at a scratch account. Today nothing here creates a billable resource,
but that changes the moment a sink test is added.

Without a key, every run block is skipped — a cheap way to confirm the test files
parse:

```text
Failure! 0 passed, 0 failed, 1 skipped.
```

A syntax error looks different: it names a file and a line instead of reporting a
connection failure.

## Leftovers

The sibling modules run `scripts/check-orphans.sh` after the apply tests to fail
the job on anything left behind. **Here it is a deliberate no-op**, and
`tests/orphan-check/` is empty: the provider ships no data source that enumerates
namespace export sinks, and there is no account-wide listing endpoint. Nothing can
be read back, so there is nothing to compare against. The script still runs and
prints that, so the gap shows in the job log rather than being invisible.

A sink belongs to a namespace, so destroying the namespace removes it. To look for
one by hand, open the namespace in the Temporal Cloud UI and check its Export
configuration, or:

```bash
tcld namespace export s3 describe --namespace <namespace>.<account_id>
tcld namespace export gcs describe --namespace <namespace>.<account_id>
```

If a `temporalcloud_namespace_export_sinks` data source is ever added, implement
the check in `tests/orphan-check/` and `scripts/check-orphans.sh` the way the
namespace module does.

Test resources are prefixed so they are identifiable:

| Prefix | Created by |
| --- | --- |
| `yulei-tftest-<random>` | `*.tftest.hcl`, via `setup/` |
| `yulei-tflocal-*` | `local/`, which is never applied — these names appear only in configuration |

The `examples/` directories are not covered by this prefix; they create `ex-s3`
and `ex-gcs`. Example code is published to the Terraform Registry, so it carries no
test-specific naming.

[CONTRIBUTING.md](../CONTRIBUTING.md) explains why the layers are split this way.
