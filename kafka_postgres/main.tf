# ==============================
# PostgreSQL Deployment
# ==============================
resource "helm_release" "postgresql" {
  count            = contains(var.infrastructure, "postgresql") ? 1 : 0
  name             = "postgresql"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "postgresql"
  version          = "16.7.27"
  namespace        = var.openshift_project_name
  create_namespace = false
  timeout          = 900  # 15 minutes timeout
  wait             = true
  wait_for_jobs    = false
  
  # Database configuration
  set {
    name  = "auth.username"
    value = var.postgresql_username
  }
  
  set {
    name  = "auth.database"
    value = var.postgresql_database
  }
  
  # Storage configuration
  set {
    name  = "primary.persistence.size"
    value = var.persistence_storage_size
  }
  
  set {
    name  = "primary.persistence.storageClass"
    value = var.persistence_storage_class
  }

  # Critical OpenShift Security Context Configuration
  set {
    name  = "global.compatibility.openshift.adaptSecurityContext"
    value = "auto"
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
  
  set {
    name  = "volumePermissions.enabled"
    value = "false"
  }
  
  set {
    name  = "shmVolume.enabled"
    value = "false"
  }
}

# ==============================
# Kafka Deployment
# ==============================
resource "helm_release" "kafka" {
  count            = contains(var.infrastructure, "kafka") ? 1 : 0
  name             = "my-kafka"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "kafka"
  version          = "32.4.3"
  namespace        = var.openshift_project_name
  create_namespace = false
  timeout          = 900  # 15 minutes timeout
  wait             = true
  wait_for_jobs    = false
  
  set {
    name  = "replicaCount"
    value = "3"
  }
  
  set {
    name  = "zookeeper.replicaCount"
    value = "3"
  }
  
  set {
    name  = "persistence.size"
    value = "10Gi"
  }
  
  set {
    name  = "persistence.storageClass"
    value = var.persistence_storage_class
  }

  # Critical OpenShift Security Context Configuration
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
  
  set {
    name  = "volumePermissions.enabled"
    value = "false"
  }
}
