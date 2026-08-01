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

| File | Covers | Creates |
| --- | --- | --- |
| `disabled.tftest.hcl` | `create_namespace_export_sink = false` declares no resource and every output falls back | nothing (applies an empty plan) |
| `destination.tftest.hcl` | Every plan-time rule, at `command = plan`: exactly one destination, the fully qualified namespace, the three S3 field rules and the two GCS service account rules | nothing |

Each case in `destination.tftest.hcl` is aimed at exactly one rule and leaves the
rest satisfied, so neutralising any single rule turns exactly one run block red.

## What is not apply-tested, and why

**Creating an export sink is not covered on apply.** It is the whole of this
module's resource surface, so the gap is worth stating plainly rather than
burying: `local/` proves the configuration type-checks, and nothing proves
Temporal Cloud accepts it.

A sink is only useful against a destination that exists, and Temporal's own
guidance is to pre-create the IAM role when configuring Export via Terraform.
There is no dry-run flag: the Cloud UI's **Verify** button has no Terraform
equivalent. Applying against placeholder values gives at best a sink that never
delivers, and a test that always fails is worse than none.

## External access required to make this suite real

This is the full list of what a maintainer would have to hold before a sink could
be created by an automated test. None of it can be stood up from inside
`terraform test`.

**Temporal Cloud**

1. `TEMPORAL_CLOUD_API_KEY` for an account that may **create namespaces** — a sink
   attaches to a namespace, so the test has to create one to attach to. This is
   the secret the workflow already uses; the suite needs nothing more from
   Temporal Cloud than it already has.
2. An account **entitled to the region the bucket is in**. The bucket region and
   the namespace region must match, and entitlements are a per-account subset of
   the published list, so the region cannot be chosen after the bucket exists.
   `tests/setup/` exposes `available_regions` for that check.
3. No other entitlement is required. Export is configured per namespace, not
   enabled per account.

**Account safety: a shared account is acceptable for this module.** A sink is
scoped to one namespace and is destroyed with it, so a test that creates its own
namespace cannot disturb anything else on the account. This module is the
exception in the family — the audit log sink and metrics endpoint modules both
replace account-wide state and need a dedicated, disposable account.

The cloud side is yours, in an account you control:

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

### What stays unverifiable until that access exists

Be clear about what the current suite does **not** establish, so nobody reads a
green run as more than it is:

- **That Temporal Cloud accepts any sink configuration at all.** No test reaches
  the create path, so nothing confirms the API takes `s3` or `gcs` as this module
  assembles them.
- **Any value the API returns.** Every assertion here is on a `try()` fallback or
  a rejected plan. No output is ever compared against something Temporal Cloud
  produced, so `namespace_export_sink_id`, `_namespace`, `_s3` and `_gcs` are
  unproven beyond their fallbacks.
- **The region-pair and trust-policy failures above**, which are exactly the two
  things a consumer is most likely to get wrong.
- **`enabled` and `timeouts` end to end.** `local/` proves they type-check;
  nothing proves the provider does anything with them.

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
Failure! 0 passed, 0 failed, 9 skipped.
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
| `yulei-tftest-nes-<random>` | `*.tftest.hcl`, via `setup/` |
| `yulei-tflocal-*` | `local/`, which is never applied — these names appear only in configuration |

The `examples/` directories are not covered by this prefix; they create `ex-s3`
and `ex-gcs`. Example code is published to the Terraform Registry, so it carries no
test-specific naming.

[CONTRIBUTING.md](../CONTRIBUTING.md) explains why the layers are split this way.
