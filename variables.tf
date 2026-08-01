variable "create_namespace_export_sink" {
  description = "Controls if the namespace export sink should be created. Set to `false` to disable the module without removing the call"
  type        = bool
  default     = true
}

################################################################################
# Sink
################################################################################

variable "namespace" {
  description = "The namespace to export from, as its fully qualified ID in the form `<namespace>.<account_id>` — not the bare namespace name. Feed it the `namespace_id` output of the namespace module, or the `id` of a `temporalcloud_namespace` resource or data source. Required unless `create_namespace_export_sink` is `false`"
  type        = string
  default     = ""

  # The bare name is the likely mistake here, and the API's rejection of it does
  # not say what the correct form is. Catch it during plan instead.
  validation {
    condition     = var.namespace == "" || can(regex("^[a-zA-Z0-9-]+\\.[a-zA-Z0-9]+$", var.namespace))
    error_message = "The namespace must be the fully qualified namespace ID `<namespace>.<account_id>`, for example `orders-prod.a1b2c`, not the bare namespace name."
  }
}

variable "sink_name" {
  description = "Name of the export sink, unique within the namespace. Cannot be changed once set — a new value replaces the sink. Required unless `create_namespace_export_sink` is `false`"
  type        = string
  default     = ""
}

variable "enabled" {
  description = "Whether the sink actively exports. Defaults to `true` when omitted. Setting it to `false` keeps the sink and its configuration but stops the export"
  type        = bool
  default     = null
}

################################################################################
# Destinations
#
# Exactly one of `s3` and `gcs` must be set. The check spans both variables, so
# it lives in a resource precondition in main.tf rather than here.
################################################################################

variable "s3" {
  description = "Amazon S3 destination. The bucket must already exist and be in the same region as the namespace, and `role_name` must name an IAM role in `aws_account_id` that Temporal Cloud can assume and that can write to the bucket. See the README for the prerequisites. Mutually exclusive with `gcs`"
  type = object({
    aws_account_id = string
    bucket_name    = string
    region         = string
    role_name      = string
    kms_arn        = optional(string)
  })
  default = null

  # try(<check>, true) throughout: the functions below raise on a null argument,
  # so a null object or an omitted optional attribute must fall through to true
  # rather than be guarded operand by operand.
  validation {
    condition     = try(length(regexall("^[0-9]{12}$", var.s3.aws_account_id)) > 0, true)
    error_message = "The s3.aws_account_id must be a 12-digit AWS account ID."
  }

  # role_name is a role NAME, not an ARN. The account is supplied separately.
  validation {
    condition     = try(length(regexall("^[^/:]+$", var.s3.role_name)) > 0, true)
    error_message = "The s3.role_name must be the IAM role name only, for example `temporal-cloud-export`, not its ARN or path."
  }

  validation {
    condition     = try(startswith(var.s3.kms_arn, "arn:aws:kms:"), true)
    error_message = "The s3.kms_arn must be a KMS key ARN beginning with `arn:aws:kms:`."
  }
}

variable "gcs" {
  description = "Google Cloud Storage destination. The bucket must already exist, be single-region, and be in the same region as the namespace. Identify the service account Temporal Cloud impersonates either with `service_account_email`, or with both `service_account_id` and `gcp_project_id`. See the README for the prerequisites. Mutually exclusive with `s3`"
  type = object({
    bucket_name           = string
    region                = string
    gcp_project_id        = optional(string)
    service_account_email = optional(string)
    service_account_id    = optional(string)
  })
  default = null

  validation {
    condition = try(
      var.gcs.service_account_email != null ||
      (var.gcs.service_account_id != null && var.gcs.gcp_project_id != null),
      true
    )
    error_message = "Set gcs.service_account_email, or set both gcs.service_account_id and gcs.gcp_project_id."
  }

  validation {
    condition     = try(length(regexall("^[^\\s]+@[^\\s]+\\.iam\\.gserviceaccount\\.com$", var.gcs.service_account_email)) > 0, true)
    error_message = "The gcs.service_account_email must look like `<service-account-id>@<gcp-project-id>.iam.gserviceaccount.com`."
  }
}

################################################################################
# Timeouts
################################################################################

variable "timeouts" {
  description = "Create and delete timeouts, as duration strings such as `30s` or `2h45m`"
  type = object({
    create = optional(string)
    delete = optional(string)
  })
  default = {}
}
