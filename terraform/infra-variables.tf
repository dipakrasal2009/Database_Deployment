# PostgreSQL configuration values (set as needed)
variable "postgresql_username" {
  type    = string
  default = "postgres"
}

variable "postgresql_database" {
  type    = string
  default = "mydatabase"
}

variable "persistence_storage_class" {
  type    = string
  default = "managed-csi"
}

variable "resources_preset" {
  ## ref: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/
  ## @param primary.resourcesPreset Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if primary.resources is set (primary.resources is recommended for production).
  ## More information: https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15
  description = "PostgreSQL Primary resource requests and limits"
  type        = string
  default     = "nano"
}

variable "postgresql_architecture" {
  description = "PostgreSQL architecture (standalone or replication)"
  type        = string
  default     = "standalone"
}

# Kafka configuration values (set as needed)

# variable "kafka_replica_count" {
#   description = "Number of Kafka replicas"
#   type        = number
#   default     = 3
# }

# variable "kafka_resources_preset" {
#   type    = string
#   default = "nano"
# }

# variable "kafka_storage_class" {
#   type    = string
#   default = "managed-csi"
# }

# variable "kafka_topics" {
#   description = "List of Kafka topics to create"
#   type        = list(string)
#   default     = []
# }

# variable "kafka_partitions" {
#   description = "Default partition count for each topic (can be overridden per-topic later if desired)."
#   type        = number
#   default     = 1
# }

# variable "kafka_topic_replication_factor" {
#   description = "Default replica factor for each topic."
#   type        = number
#   default     = 3
# }

# variable "strimzi_namespace" {
#   type        = string
#   description = "Namespace name where strimzi operator will be deployed. Shuld be same for every run in same cluster"
#   default     = "strimzi-operator"
# }

# variable "zookeeper_replicas" {
#   type        = string
#   description = "Number of zookeeper replicas"
#   default     = 3
# }

# variable "kafka_strimzi_operator_version" {
#   type        = string
#   description = "Version of Kafka strimzi operator to install"
#   default     = "0.47.0"
# }

# variable "kafka_version" {
#   description = "Kafka version embedded in the Strimzi images."
#   type        = string
#   default     = "3.9.1"
# }

# variable "oauth_client_id" {
#   type = string
# }
#
# variable "oauth_client_secret_key" {
#   type = string
# }
#
# variable "oauth_token_endpoint" {
#   type = string
# }
#
# variable "oauth_issuer" {
#   type = string
# }
#
# variable "oauth_jwks_endpoint" {
#   type = string
# }
#
