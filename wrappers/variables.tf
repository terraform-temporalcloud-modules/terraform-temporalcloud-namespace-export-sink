variable "defaults" {
  description = "Default values applied to every export sink in `items`, unless that item overrides them. Accepts any input the root module accepts"
  type        = any
  default     = {}
}

variable "items" {
  description = "Map of export sinks to create. Each key becomes an instance of the module and each value accepts any input the root module accepts"
  type        = any
  default     = {}
}
