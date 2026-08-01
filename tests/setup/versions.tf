terraform {
  required_version = ">= 1.5.7"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    # Needed for the temporalcloud_regions data source. Configuration comes from
    # the provider block in the calling .tftest.hcl file.
    temporalcloud = {
      source  = "temporalio/temporalcloud"
      version = ">= 1.6.0"
    }
  }
}
