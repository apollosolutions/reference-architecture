# Variables you're expected to set

variable "github_token" {
  description = "github user token"
}

variable "apollo_key" {
  description = "Apollo key for checks, publishes, and Router Uplink"
}

variable "apollo_graph_id" {
  description = "Apollo graph ID for checks, publishes, and Router Uplink"
}

variable "pq_dev_id" {
  description = "Apollo PQ ID for the dev variant"
}

variable "pq_prod_id" {
  description = "Apollo PQ ID for the prod variant"
}

# Variables you can override if you know what you're doing

variable "demo_name" {
  default     = "reference-architecture"
  description = "name of the demo (used for graphs and github repos)"
  validation {
    condition     = length(var.demo_name) < 24
    error_message = "demo_name max length is 24"
  }
}
