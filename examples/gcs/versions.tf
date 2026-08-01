terraform {
  required_version = ">= 1.5.7"

  required_providers {
    temporalcloud = {
      source  = "temporalio/temporalcloud"
      version = ">= 1.6.0"
    }
  }
}
