# Intentionally empty.
#
# In the sibling modules this directory holds a data source that lists whatever
# the apply tests may have left behind. The temporalcloud provider ships no data
# source for namespace export sinks, so there is nothing to read: a sink can only
# be described one namespace at a time, and the account cannot be enumerated.
#
# The directory is kept so the layout matches the other modules and so there is an
# obvious place to implement the check if such a data source appears.
# scripts/check-orphans.sh explains the same thing in the CI job log and exits 0
# without invoking Terraform.
