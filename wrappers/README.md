# Wrapper for the Temporal Cloud namespace export sink module

The configuration in `wrappers/` implements the single module wrapper pattern, which allows managing
several copies of this module from one call in places where the native `for_each` on a module block is
not available — most commonly Terragrunt.

This wrapper adds no functionality of its own. Every key under `items` accepts any input the root
module accepts, and `defaults` supplies values shared by all items.

Contributors: see [CONTRIBUTING.md](../CONTRIBUTING.md) for how these files are maintained.

## Usage with Terraform

Each item still needs its own bucket and its own IAM role or service account, created outside
Terraform or by a separate configuration — see the [prerequisites](../README.md#prerequisites).

```hcl
module "export_sinks" {
  source = "terraform-temporalcloud-modules/namespace-export-sink/temporalcloud//wrappers"

  # Shared by every item unless the item overrides it.
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
        kms_arn        = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
      }
    }

    # Destinations may be mixed across items — each sink writes to exactly one.
    audit = {
      namespace = module.audit_namespace.namespace_id
      sink_name = "audit-archive"

      gcs = {
        bucket_name           = "acme-temporal-export-audit"
        region                = "us-central1"
        service_account_email = "temporal-cloud-export@acme-prod.iam.gserviceaccount.com"
      }
    }
  }
}
```

Outputs are keyed by the same map keys:

```hcl
output "orders_sink_id" {
  value = module.export_sinks.wrapper["orders"].namespace_export_sink_id
}
```

## Usage with Terragrunt

`terragrunt.hcl`:

```hcl
terraform {
  source = "tfr:///terraform-temporalcloud-modules/namespace-export-sink/temporalcloud//wrappers?version=1.0.0"
  # Alternative source:
  # source = "git::git@github.com:terraform-temporalcloud-modules/terraform-temporalcloud-namespace-export-sink.git//wrappers?ref=v1.0.0"
}

inputs = {
  defaults = {
    enabled = true
  }

  items = {
    orders = {
      namespace = "orders-prod.a1b2c"
      sink_name = "orders-archive"

      s3 = {
        aws_account_id = "123456789012"
        bucket_name    = "acme-temporal-export-orders"
        region         = "us-east-1"
        role_name      = "temporal-cloud-export"
      }
    }
  }
}
```

Pin `?version=` / `?ref=` to a released tag rather than a branch, so a wrapper upgrade is a deliberate
change.

## Inputs

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| `defaults` | Default values applied to every export sink in `items`, unless that item overrides them | `any` | `{}` |
| `items` | Map of export sinks to create; each key becomes an instance of the module | `any` | `{}` |

## Outputs

| Name | Description |
| ---- | ----------- |
| `wrapper` | Map of module outputs, keyed by the same keys as `items` |
