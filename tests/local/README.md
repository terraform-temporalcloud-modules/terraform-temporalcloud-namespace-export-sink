# Local regression coverage

This directory is **not an example** — do not copy it. See [examples/](../../examples) for usage.

## Why it exists

The `examples/` directories source the *published* module from the Terraform Registry so they are
copy-pasteable for consumers. The tradeoff is that they validate the last release rather than the code
in this repository: a renamed or removed variable would pass CI unnoticed.

This directory sources the module by relative path (`../../`) and passes **every** input, so
`terraform validate` fails here the moment the variable surface changes incompatibly. It covers:

| Module call | What it proves |
| --- | --- |
| `all_inputs_s3` | Every input the module accepts, with an S3 destination including `kms_arn` |
| `all_inputs_gcs` | The GCS destination identified by `service_account_email` |
| `gcs_service_account_id` | The other accepted form: `service_account_id` plus `gcp_project_id` |
| `disabled` | `create_namespace_export_sink = false` produces no resources and every output falls back via `try()` |
| `minimal` | The module works with only `namespace`, `sink_name` and one destination |
| `wrapper` | `wrappers/` accepts `defaults` / `items` and passes them through, with S3 and GCS items side by side |

A sink writes to exactly one destination, so the S3 and GCS cases need separate module calls rather
than one call carrying both.

`outputs.tf` references every output, so a broken output expression fails here rather than in a
consumer's plan.

The identifiers here are placeholders. They are never applied — this directory is only ever
`terraform validate`d, and no bucket, IAM role or account referenced by it exists.

## Maintenance

When you add a variable to the root module, **add it here in the same PR** — the `wrapper-sync` hook
guards `wrappers/main.tf`, but nothing else would catch an untested input. Adding it to `examples/` has
to wait until the next release publishes it.

CI discovers this directory automatically: the workflow globs for any directory containing a `.tf`
file with `required_version`, so no matrix entry needs maintaining.

## Running it

```bash
terraform init
terraform validate
```

`terraform plan` additionally requires `TEMPORAL_CLOUD_API_KEY`, because the provider authenticates at
configure time even when no resources would be created. Do not apply this directory.
