# Amazon S3 export sink example

Configuration in this directory creates a Temporal Cloud namespace and configures Workflow History
Export from it to an Amazon S3 bucket.

The namespace is created here so the example reads end to end. In a real configuration the namespace
usually already exists — pass its ID directly, or read it with the `temporalcloud_namespace` data
source. Either way, feed the module the fully qualified **ID** (`<namespace>.<account_id>`), not the
bare name; taking it from a module output rather than typing it is the point of the wiring shown here.

## Before you run this

**The bucket and the IAM role are not created by this configuration.** Temporal Cloud validates the
destination while creating the sink, so the apply fails unless both already exist:

- an S3 bucket in `us-east-1` — the same region as the namespace, which is `aws-us-east-1` in Temporal
  Cloud's own region format
- an IAM role in the AWS account named by `aws_account_id`, whose trust policy admits Temporal Cloud's
  export principals and whose permissions policy allows writing to that bucket

Get the role from Temporal Cloud's CloudFormation template rather than hand-writing the trust policy —
see [Prerequisites](../../README.md#prerequisites) and
[Exporting Workflow Event History to AWS S3](https://docs.temporal.io/cloud/export/aws-export-s3).

Then edit `main.tf` to point at your own bucket name, region and AWS account ID. The `regions` value
must also be one your Temporal Cloud account is entitled to use.

## Usage

To run this example you need to execute:

```bash
export TEMPORAL_CLOUD_API_KEY="<your-api-key>"

terraform init
terraform plan
terraform apply
```

Note that this example creates resources which cost money. Run `terraform destroy` when you no longer
need them.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_temporalcloud"></a> [temporalcloud](#requirement\_temporalcloud) | >= 1.6.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_export_sink"></a> [export\_sink](#module\_export\_sink) | terraform-temporalcloud-modules/namespace-export-sink/temporalcloud | ~> 1.0 |
| <a name="module_namespace"></a> [namespace](#module\_namespace) | terraform-temporalcloud-modules/namespace/temporalcloud | ~> 1.0 |

## Resources

No resources.

## Inputs

No inputs.

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_namespace_export_sink_enabled"></a> [namespace\_export\_sink\_enabled](#output\_namespace\_export\_sink\_enabled) | Whether the sink is actively exporting |
| <a name="output_namespace_export_sink_id"></a> [namespace\_export\_sink\_id](#output\_namespace\_export\_sink\_id) | The unique identifier of the export sink |
| <a name="output_namespace_export_sink_s3"></a> [namespace\_export\_sink\_s3](#output\_namespace\_export\_sink\_s3) | The resolved Amazon S3 destination configuration |
| <a name="output_namespace_id"></a> [namespace\_id](#output\_namespace\_id) | The fully qualified ID of the namespace being exported |
<!-- END_TF_DOCS -->

## License

Apache-2.0 licensed. See [LICENSE](../../LICENSE).
