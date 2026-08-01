# Temporal Cloud Namespace Export Sink Terraform module

[![CI](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-namespace-export-sink/actions/workflows/pre-commit.yml/badge.svg?branch=main)](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-namespace-export-sink/actions/workflows/pre-commit.yml?query=branch%3Amain)
[![Apply Tests](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-namespace-export-sink/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-namespace-export-sink/actions/workflows/test.yml?query=branch%3Amain)

Terraform module which configures [Workflow History Export](https://docs.temporal.io/cloud/export) for
a [Temporal Cloud](https://temporal.io/cloud) namespace, writing closed Workflow Histories to an Amazon
S3 or Google Cloud Storage bucket you own.

Both badges report the state of `main`. **CI** covers formatting, linting,
documentation and `terraform validate`, and runs on every pull request and again
after merge. **Apply Tests** runs against a live Temporal Cloud account, weekly and
on demand — see [tests/README.md](tests/README.md) for what it does and does not
cover, because creating a sink needs cloud infrastructure that CI does not have.

## Requirements

The `temporalcloud` provider authenticates with an API key, read from the `TEMPORAL_CLOUD_API_KEY`
environment variable:

```bash
export TEMPORAL_CLOUD_API_KEY="<your-api-key>"
```

The provider authenticates when it initialises, so a key is needed even for a `terraform plan` that
would create nothing. Keep the key out of version control — an untracked `.env` file rather than a
committed `.tfvars`.

**This module does not create the bucket, the IAM role or the service account.** Read the next section
before your first apply; without that setup, creation fails with a permissions error.

## Prerequisites

Temporal Cloud validates the destination while it creates the sink: it assumes your IAM role — or
impersonates your service account — and writes a test object to the bucket. There is no
"configure now, wire up later" path. If the destination is not reachable, `terraform apply` fails and
no sink is created.

The bucket lives in **your** cloud account. `aws_account_id` and `role_name` refer to your AWS account
and a role in it, not to anything of Temporal's.

### Amazon S3

1. **A bucket in the same region as the namespace.** Temporal Cloud requires this; the bucket region
   and the namespace region must match. Note the two use different region ID formats — the namespace
   is in `aws-us-east-1`, the bucket is in `us-east-1`.
2. **An IAM role Temporal Cloud can assume**, in the same AWS account as the bucket. It needs:
   - a **trust policy** allowing Temporal Cloud's export principals to call `sts:AssumeRole` on it.
     Temporal Cloud rotates across [several intermediary roles](https://docs.temporal.io/cloud/export/aws-export-s3)
     rather than using one fixed principal, so do not hand-write this list — it is the part most likely
     to be wrong and it changes.
   - a **permissions policy** allowing it to write objects into the bucket, and, when the bucket uses a
     customer-managed key, to use that key (`kms:GenerateDataKey` and related actions on the key ARN).
3. **Optionally a KMS key**, if you want the exported objects encrypted with a customer-managed key.
   Pass its ARN as `s3.kms_arn`.

**Get the trust policy from Temporal, do not compose it yourself.** Temporal Cloud publishes a
CloudFormation template that creates the role with the correct trust relationship and bucket
permissions for your namespace. In the Temporal Cloud UI, open the namespace, choose **Configure** on
the Export card, and follow either the automated path (which opens the CloudFormation console with the
values pre-filled) or the manual path (which gives you the template URL to download). Full walkthrough:
[Exporting Workflow Event History to AWS S3](https://docs.temporal.io/cloud/export/aws-export-s3).

Then create the role however you normally manage AWS — the CloudFormation stack, or your own
`aws_iam_role` built from the same policies — note its **name**, and pass that name here. `role_name`
is the bare name, not an ARN; it is resolved inside `aws_account_id`.

### Google Cloud Storage

1. **A single-region bucket in the same region as the namespace.** Multi-region buckets are not
   supported — choose *Region*, not *Multi-region*, when creating it. Enable CMEK if you need
   customer-managed encryption.
2. **A service account in the same project**, which Temporal Cloud impersonates, granted permission to
   write to that bucket. Temporal Cloud rotates across several intermediary service accounts, so as
   with AWS, take the binding from the
   [Temporal setup guide](https://docs.temporal.io/cloud/export/gcp-export-gcs) rather than composing
   it yourself.
3. Note the **bucket name**, the **project ID** and the **service account**.

Identify the service account either way — the two forms are equivalent:

```hcl
# By email. The provider derives the ID and project from it.
service_account_email = "temporal-cloud-export@acme-prod.iam.gserviceaccount.com"

# Or by ID and project.
service_account_id = "temporal-cloud-export"
gcp_project_id     = "acme-prod"
```

Supplying only one of `service_account_id` / `gcp_project_id`, with no email, fails during plan.

## Usage

### Amazon S3

```hcl
module "export_sink" {
  source  = "terraform-temporalcloud-modules/namespace-export-sink/temporalcloud"
  version = "~> 1.0"

  # The fully qualified namespace ID, not the bare name — see Notes.
  namespace = module.namespace.namespace_id
  sink_name = "orders-archive"

  s3 = {
    aws_account_id = "123456789012"
    bucket_name    = "acme-temporal-export-orders"
    region         = "us-east-1"
    role_name      = "temporal-cloud-export"
  }
}
```

### Google Cloud Storage

```hcl
module "export_sink" {
  source  = "terraform-temporalcloud-modules/namespace-export-sink/temporalcloud"
  version = "~> 1.0"

  namespace = module.namespace.namespace_id
  sink_name = "orders-archive"

  gcs = {
    bucket_name           = "acme-temporal-export-orders"
    region                = "us-central1"
    service_account_email = "temporal-cloud-export@acme-prod.iam.gserviceaccount.com"
  }
}
```

### Pausing an export

`enabled = false` keeps the sink and its configuration but stops the export. Use it to pause rather
than destroying and recreating the sink, which would lose the name:

```hcl
module "export_sink" {
  source  = "terraform-temporalcloud-modules/namespace-export-sink/temporalcloud"
  version = "~> 1.0"

  namespace = module.namespace.namespace_id
  sink_name = "orders-archive"
  enabled   = false

  s3 = {
    aws_account_id = "123456789012"
    bucket_name    = "acme-temporal-export-orders"
    region         = "us-east-1"
    role_name      = "temporal-cloud-export"
  }
}
```

## Notes

Behaviours worth knowing before you plan:

- **`namespace` is the fully qualified ID, not the namespace name.** It has the form
  `<namespace>.<account_id>`, for example `orders-prod.a1b2c`. Passing the bare name is the most common
  mistake with this resource; this module rejects it during plan rather than letting the API refuse it
  with a message that does not say what the right form is. Wire it from
  `module.namespace.namespace_id`, from `temporalcloud_namespace.this.id`, or from the
  `temporalcloud_namespace` data source.
- **The bucket must be in the same region as the namespace**, and the two are written differently:
  `aws-us-east-1` for the namespace, `us-east-1` for the bucket. A GCS bucket must additionally be
  single-region.
- **Exactly one of `s3` and `gcs`.** Setting both, or neither, fails during plan.
- **`sink_name` cannot be changed.** A new value replaces the sink, which stops and restarts the
  export.
- **`role_name` is a name, not an ARN.** The account comes from `aws_account_id`.
- **Export is not automatically replicated on a High Availability namespace.** The configuration is
  tied to the region it was set up in and does not follow a failover. Configure the other region
  separately if you need continuous export across one.
- **The sink cannot be enumerated.** The provider offers no data source listing export sinks, so a sink
  created outside Terraform cannot be discovered from a configuration — import it, or recreate it here.

## Examples

- [s3](examples/s3) — export to an Amazon S3 bucket, with the namespace wired from the namespace module
- [gcs](examples/gcs) — export to a Google Cloud Storage bucket

Both examples create the namespace they export from so they read end to end. They still need a bucket
and a role or service account you have provisioned first.

## Managing several export sinks

The [`wrappers`](wrappers) submodule creates many sinks from one call, for use with Terragrunt or
anywhere a `for_each` on the module block is awkward:

```hcl
module "export_sinks" {
  source  = "terraform-temporalcloud-modules/namespace-export-sink/temporalcloud//wrappers"
  version = "~> 1.0"

  defaults = {
    enabled = true
  }

  items = {
    orders = {
      namespace = module.orders_namespace.namespace_id
      sink_name = "orders-archive"

      s3 = {
        aws_account_id = "123456789012"
        bucket_name    = "acme-temporal-export-orders"
        region         = "us-east-1"
        role_name      = "temporal-cloud-export"
      }
    }

    payments = {
      namespace = module.payments_namespace.namespace_id
      sink_name = "payments-archive"

      s3 = {
        aws_account_id = "123456789012"
        bucket_name    = "acme-temporal-export-payments"
        region         = "us-east-1"
        role_name      = "temporal-cloud-export"
      }
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_temporalcloud"></a> [temporalcloud](#requirement\_temporalcloud) | >= 1.6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_temporalcloud"></a> [temporalcloud](#provider\_temporalcloud) | >= 1.6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [temporalcloud_namespace_export_sink.this](https://registry.terraform.io/providers/temporalio/temporalcloud/latest/docs/resources/namespace_export_sink) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_create_namespace_export_sink"></a> [create\_namespace\_export\_sink](#input\_create\_namespace\_export\_sink) | Controls if the namespace export sink should be created. Set to `false` to disable the module without removing the call | `bool` | `true` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether the sink actively exports. Defaults to `true` when omitted. Setting it to `false` keeps the sink and its configuration but stops the export | `bool` | `null` | no |
| <a name="input_gcs"></a> [gcs](#input\_gcs) | Google Cloud Storage destination. The bucket must already exist, be single-region, and be in the same region as the namespace. Identify the service account Temporal Cloud impersonates either with `service_account_email`, or with both `service_account_id` and `gcp_project_id`. See the README for the prerequisites. Mutually exclusive with `s3` | <pre>object({<br/>    bucket_name           = string<br/>    region                = string<br/>    gcp_project_id        = optional(string)<br/>    service_account_email = optional(string)<br/>    service_account_id    = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace to export from, as its fully qualified ID in the form `<namespace>.<account_id>` — not the bare namespace name. Feed it the `namespace_id` output of the namespace module, or the `id` of a `temporalcloud_namespace` resource or data source. Required unless `create_namespace_export_sink` is `false` | `string` | `""` | no |
| <a name="input_s3"></a> [s3](#input\_s3) | Amazon S3 destination. The bucket must already exist and be in the same region as the namespace, and `role_name` must name an IAM role in `aws_account_id` that Temporal Cloud can assume and that can write to the bucket. See the README for the prerequisites. Mutually exclusive with `gcs` | <pre>object({<br/>    aws_account_id = string<br/>    bucket_name    = string<br/>    region         = string<br/>    role_name      = string<br/>    kms_arn        = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_sink_name"></a> [sink\_name](#input\_sink\_name) | Name of the export sink, unique within the namespace. Cannot be changed once set — a new value replaces the sink. Required unless `create_namespace_export_sink` is `false` | `string` | `""` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Create and delete timeouts, as duration strings such as `30s` or `2h45m` | <pre>object({<br/>    create = optional(string)<br/>    delete = optional(string)<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_namespace_export_sink_enabled"></a> [namespace\_export\_sink\_enabled](#output\_namespace\_export\_sink\_enabled) | Whether the sink is actively exporting |
| <a name="output_namespace_export_sink_gcs"></a> [namespace\_export\_sink\_gcs](#output\_namespace\_export\_sink\_gcs) | The resolved Google Cloud Storage destination configuration. Null when the sink writes to Amazon S3 |
| <a name="output_namespace_export_sink_id"></a> [namespace\_export\_sink\_id](#output\_namespace\_export\_sink\_id) | The unique identifier of the export sink |
| <a name="output_namespace_export_sink_name"></a> [namespace\_export\_sink\_name](#output\_namespace\_export\_sink\_name) | The name of the export sink |
| <a name="output_namespace_export_sink_namespace"></a> [namespace\_export\_sink\_namespace](#output\_namespace\_export\_sink\_namespace) | The fully qualified ID of the namespace the sink exports from, in the form `<namespace>.<account_id>` |
| <a name="output_namespace_export_sink_s3"></a> [namespace\_export\_sink\_s3](#output\_namespace\_export\_sink\_s3) | The resolved Amazon S3 destination configuration. Null when the sink writes to Google Cloud Storage |
<!-- END_TF_DOCS -->

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow, how the test layers are arranged,
and why this module is released separately from the namespace module.

## License

Apache-2.0 licensed. See [LICENSE](LICENSE).
