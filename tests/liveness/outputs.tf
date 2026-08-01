output "region_count" {
  description = "Number of regions the API returned. Any value above zero means the API answered and the key was accepted"
  value       = length(data.temporalcloud_regions.liveness.regions)
}

output "regions" {
  description = "Region IDs this account may use, reported so a failing suite shows what the account actually offers"
  value       = sort([for r in data.temporalcloud_regions.liveness.regions : r.id])
}
