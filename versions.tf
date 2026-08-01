terraform {
  # 1.5.7 is the floor for `optional()` object attributes with defaults, which
  # this module relies on for its nested attribute variables.
  required_version = ">= 1.5.7"

  required_providers {
    temporalcloud = {
      source = "temporalio/temporalcloud"
      # Permissive lower bound on purpose: consumers must be able to adopt newer
      # provider releases without waiting for a release of this module.
      version = ">= 1.6.0"
    }
  }
}
