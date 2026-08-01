terraform {
  # Must match the root module's floor: this directory is how CI proves the
  # declared minimum Terraform version can actually build the module.
  required_version = ">= 1.5.7"

  required_providers {
    temporalcloud = {
      source  = "temporalio/temporalcloud"
      version = ">= 1.6.0"
    }
  }
}
