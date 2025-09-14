# ==============================
# PostgreSQL Deployment
# ==============================
resource "helm_release" "postgresql" {
  count      = contains(var.infrastructure, "postgresql") ? 1 : 0
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "16.7.27"
  dependency_update =  true
  namespace  = var.openshift_project_name

  create_namespace = false

  set {
    name  = "auth.username"
    value = var.postgresql_username
  }

  set {
    name  = "auth.database"
    value = var.postgresql_database
  }

  set {
    name  = "primary.persistence.size"
    value = var.persistence_storage_size
  }

  set {
    name  = "primary.persistence.storageClass"
    value = var.persistence_storage_class
  }
}

# ==============================
# Kafka Deployment
# ==============================
resource "helm_release" "kafka" {
  count      = contains(var.infrastructure, "kafka") ? 1 : 0
  name       = "my-kafka"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kafka"
  version    = "32.4.3"
  namespace  = var.openshift_project_name

  create_namespace = false

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
}

