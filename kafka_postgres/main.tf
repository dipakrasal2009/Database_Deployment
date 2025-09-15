# ==============================
# PostgreSQL Deployment via Helm
# ==============================
resource "helm_release" "postgresql" {
  # Deploy PostgreSQL only if "postgresql" is present in var.infrastructure
  count            = contains(var.infrastructure, "postgresql") ? 1 : 0
  
  # Helm release name
  name             = "postgresql"
  
  # Bitnami Helm chart for PostgreSQL (from Docker Hub OCI registry)
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "postgresql"
  version          = "16.7.27"
  
  # Deploy into the OpenShift project/namespace defined in variables
  namespace        = var.openshift_project_name
  create_namespace = false
  
  # Timeout and behavior during installation
  timeout          = 900  # 15 minutes timeout
  wait             = true
  wait_for_jobs    = false
  
  # ------------------------------
  # Database configuration
  # ------------------------------
  set {
    name  = "auth.username"
    value = var.postgresql_username
  }
  
  set {
    name  = "auth.database"
    value = var.postgresql_database
  }
  
  # ------------------------------
  # Storage configuration for PostgreSQL primary node
  # ------------------------------
  set {
    name  = "primary.persistence.size"
    value = var.persistence_storage_size
  }
  
  set {
    name  = "primary.persistence.storageClass"
    value = var.persistence_storage_class
  }

  # ------------------------------
  # Security Context configuration (important for OpenShift SCC policies)
  # ------------------------------
  set {
    name  = "global.compatibility.openshift.adaptSecurityContext"
    value = "auto" # automatically adapts chart to OpenShift security model
  }
  
  set {
    name  = "primary.podSecurityContext.enabled"
    value = "false"
  }
  
  set {
    name  = "primary.containerSecurityContext.enabled"
    value = "false"
  }
  
  set {
    name  = "primary.containerSecurityContext.runAsNonRoot"
    value = "true"
  }
  
  set {
    name  = "primary.containerSecurityContext.allowPrivilegeEscalation"
    value = "false"
  }
  
  set {
    name  = "primary.containerSecurityContext.seccompProfile.type"
    value = "RuntimeDefault"
  }
  
  set {
    name  = "primary.containerSecurityContext.capabilities.drop[0]"
    value = "ALL"
  }
  
  # Disable volume permission init container (since OpenShift handles this differently)
  set {
    name  = "volumePermissions.enabled"
    value = "false"
  }
  
  # Disable shared memory volume (not required in OpenShift setups)
  set {
    name  = "shmVolume.enabled"
    value = "false"
  }
}

# ==============================
# Kafka Deployment via Helm
# ==============================
resource "helm_release" "kafka" {
  # Deploy Kafka only if "kafka" is present in var.infrastructure
  count            = contains(var.infrastructure, "kafka") ? 1 : 0
  
  # Helm release name
  name             = "my-kafka"
  
  # Bitnami Helm chart for Kafka (from Docker Hub OCI registry)
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "kafka"
  version          = "32.4.3"
  
  # Deploy into the OpenShift project/namespace defined in variables
  namespace        = var.openshift_project_name
  create_namespace = false
  
  # Timeout and behavior during installation
  timeout          = 900  # 15 minutes timeout
  wait             = true
  wait_for_jobs    = false
  
  # ------------------------------
  # Kafka cluster configuration
  # ------------------------------
  set {
    name  = "replicaCount"
    value = "3" # 3 Kafka brokers for HA
  }
  
  # Zookeeper replicas required by Kafka
  set {
    name  = "zookeeper.replicaCount"
    value = "3"
  }
  
  # ------------------------------
  # Storage configuration
  # ------------------------------
  set {
    name  = "persistence.size"
    value = "10Gi"
  }
  
  set {
    name  = "persistence.storageClass"
    value = var.persistence_storage_class
  }

  # ------------------------------
  # Security Context configuration (important for OpenShift SCC policies)
  # ------------------------------
  set {
    name  = "global.compatibility.openshift.adaptSecurityContext"
    value = "auto"
  }
  
  set {
    name  = "podSecurityContext.enabled"
    value = "false"
  }
  
  set {
    name  = "containerSecurityContext.enabled"
    value = "false"
  }
  
  set {
    name  = "containerSecurityContext.runAsNonRoot"
    value = "true"
  }
  
  set {
    name  = "containerSecurityContext.allowPrivilegeEscalation"
    value = "false"
  }
  
  set {
    name  = "containerSecurityContext.seccompProfile.type"
    value = "RuntimeDefault"
  }
  
  set {
    name  = "containerSecurityContext.capabilities.drop[0]"
    value = "ALL"
  }
  
  # ------------------------------
  # Security Context for Zookeeper
  # ------------------------------
  set {
    name  = "zookeeper.podSecurityContext.enabled"
    value = "false"
  }
  
  set {
    name  = "zookeeper.containerSecurityContext.enabled"
    value = "false"
  }
  
  set {
    name  = "zookeeper.containerSecurityContext.runAsNonRoot"
    value = "true"
  }
  
  set {
    name  = "zookeeper.containerSecurityContext.allowPrivilegeEscalation"
    value = "false"
  }
  
  set {
    name  = "zookeeper.containerSecurityContext.seccompProfile.type"
    value = "RuntimeDefault"
  }
  
  # Disable volume permission init container
  set {
    name  = "volumePermissions.enabled"
    value = "false"
  }
}
