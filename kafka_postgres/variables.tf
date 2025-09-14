# Target OpenShift project/namespace
variable "openshift_project_name" {
  type        = string
  description = "Namespace to deploy Helm charts"
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9\\-]{0,61}[a-z0-9])?$", var.openshift_project_name))
    error_message = "The namespace name must be a valid Kubernetes namespace name."
  }
}

# List of infrastructure components to deploy
variable "infrastructure" {
  type        = list(string)
  description = "List of infrastructure components to deploy"
  default     = []
  validation {
    condition = alltrue([
      for component in var.infrastructure : contains(["postgresql", "kafka"], component)
    ])
    error_message = "Infrastructure components must be one of: postgresql, kafka."
  }
}

# PostgreSQL configuration
variable "postgresql_username" {
  type        = string
  description = "PostgreSQL username"
  default     = "postgres"
  validation {
    condition     = length(var.postgresql_username) > 0
    error_message = "PostgreSQL username cannot be empty."
  }
}

variable "postgresql_database" {
  type        = string
  description = "PostgreSQL database name"
  default     = "mydatabase"
  validation {
    condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_]*$", var.postgresql_database))
    error_message = "Database name must start with a letter or underscore and contain only letters, numbers, and underscores."
  }
}

# Persistent storage settings
variable "persistence_storage_class" {
  type        = string
  description = "StorageClass for persistent volumes"
  default     = "managed-csi"
  validation {
    condition     = length(var.persistence_storage_class) > 0
    error_message = "Storage class cannot be empty."
  }
}

variable "persistence_storage_size" {
  type        = string
  description = "Storage size for persistent volumes"
  default     = "5Gi"
  validation {
    condition     = can(regex("^[0-9]+(Gi|Mi|Ti)$", var.persistence_storage_size))
    error_message = "Storage size must be in format like 5Gi, 100Mi, or 1Ti."
  }
}
