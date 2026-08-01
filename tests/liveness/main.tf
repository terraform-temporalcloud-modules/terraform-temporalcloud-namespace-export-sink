# Proves the Temporal Cloud API is reachable and the API key is accepted.
#
# Reads the cheapest available data source. Creates nothing, so it costs a single
# API call and no resources.
#
# Run before the apply tests: without it, an expired or malformed key surfaces only
# after Terraform has initialised and started creating a namespace, and the failure
# reads as a test failure rather than a credentials problem.

data "temporalcloud_regions" "liveness" {}
