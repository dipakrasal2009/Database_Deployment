# ===========================================
# OpenShift Project / Namespace Configuration
# ===========================================
variable "openshift_project_name" {
  type        = string
  description = "Namespace to deploy Helm charts"

  # Validation: must match Kubernetes namespace naming rules
  # - Start with a lowercase letter or number
  # - Can contain lowercase letters, numbers, or dashes
  # - Must end with a letter or number
  # - Max length: 63 characters
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9\\-]{0,61}[a-z0-9])?$", var.openshift_project_name))
    error_message = "The namespace name must be a valid Kubernetes namespace name."
  }
}

# ===========================================
# Infrastructure Components
# ===========================================
variable "infrastructure" {
  type        = list(string)
  description = "List of infrastructure components to deploy"
  default     = []

  # Validation: only "postgresql" or "kafka" are allowed
  validation {
    condition = alltrue([
      for component in var.infrastructure : contains(["postgresql", "kafka"], component)
    ])
    error_message = "Infrastructure components must be one of: postgresql, kafka."
  }
}

# ===========================================
# PostgreSQL Configuration
# ===========================================
variable "postgresql_username" {
  type        = string
  description = "PostgreSQL username"
  default     = "postgres"

  # Validation: username must not be empty
  validation {
    condition     = length(var.postgresql_username) > 0
    error_message = "PostgreSQL username cannot be empty."
  }
}

variable "postgresql_database" {
  type        = string
  description = "PostgreSQL database name"
  default     = "mydatabase"

  # Validation: must follow PostgreSQL identifier rules
  # - Start with a letter or underscore
  # - Can contain letters, numbers, and underscores
  validation {
    condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_]*$", var.postgresql_database))
    error_message = "Database name must start with a letter or underscore and contain only letters, numbers, and underscores."
  }
}

# ===========================================
# Persistent Storage Settings
# ===========================================
variable "persistence_storage_class" {
  type        = string
  description = "StorageClass for persistent volumes"
  default     = "managed-csi"

  # Validation: must not be empty
  validation {
    condition     = length(var.persistence_storage_class) > 0
    error_message = "Storage class cannot be empty."
  }
}

variable "persistence_storage_size" {
  type        = string
  description = "Storage size for persistent volumes"
  default     = "5Gi"

  # Validation: must follow Kubernetes storage size format
  # Example: 5Gi, 100Mi, 1Ti
  validation {
    condition     = can(regex("^[0-9]+(Gi|Mi|Ti)$", var.persistence_storage_size))
    error_message = "Storage size must be in format like 5Gi, 100Mi, or 1Ti."
  }
}
