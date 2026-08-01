# Generates a unique sink and namespace name per test run.
#
# Sink names are unique within a namespace and namespace names are unique within
# an account, so fixed names would make a second run — or a concurrent one — fail
# on a name already in use, and would collide with anything a human left behind
# after a failed run.
resource "random_pet" "this" {
  length    = 2
  separator = "-"
}

# Regions this account is entitled to use.
#
# Not hardcoded: the regions an account may use are a subset of the published
# list, so a fixed ID makes the suite account-specific and can fail with
# "is not a valid Temporal Cloud region".
#
# An export sink's bucket must be in the same region as its namespace, so a sink
# test cannot pick a region freely — it must use the one the target bucket is in.
# This output exists so such a test can fail with a clear message when the account
# cannot place a namespace there, rather than with an opaque region error.
data "temporalcloud_regions" "available" {}

locals {
  # Sorted so repeat runs pick the same region and results stay comparable.
  region_ids = sort([for r in data.temporalcloud_regions.available.regions : r.id])
}
