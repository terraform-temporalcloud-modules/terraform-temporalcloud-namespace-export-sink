output "sink_name" {
  description = "Unique export sink name for this test run, prefixed `yulei-tftest-` so leftovers from an interrupted run are identifiable"
  value       = "yulei-tftest-${random_pet.this.id}"
}

output "namespace_name" {
  description = "Unique namespace name for this test run, prefixed `yulei-tftest-` so leftovers from an interrupted run are identifiable in the Temporal Cloud account"
  # `yulei-` identifies the owner, `tftest-` distinguishes test resources from
  # anything created by hand. Satisfies the namespace name constraint: 2-64
  # chars, starts with a letter, lowercase alphanumerics and hyphens, no
  # trailing hyphen.
  value = "yulei-tftest-${random_pet.this.id}"
}

output "available_regions" {
  description = "Every region this account may use. A sink test must place its namespace in the region its target bucket is in; check that region appears here before assuming a failure is a module bug"
  value       = local.region_ids
}
