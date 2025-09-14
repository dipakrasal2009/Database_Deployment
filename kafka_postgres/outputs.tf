# Output PostgreSQL connection details
output "postgresql_connection" {
  description = "PostgreSQL connection information"
  value = contains(var.infrastructure, "postgresql") ? {
    host     = "${helm_release.postgresql[0].name}.${var.openshift_project_name}.svc.cluster.local"
    port     = 5432
    database = var.postgresql_database
    username = var.postgresql_username
    password_secret = "${helm_release.postgresql[0].name}"
  } : null
  sensitive = false
}

# Output Kafka connection details
output "kafka_connection" {
  description = "Kafka connection information"
  value = contains(var.infrastructure, "kafka") ? {
    bootstrap_servers = "${helm_release.kafka[0].name}.${var.openshift_project_name}.svc.cluster.local:9092"
    internal_host     = "${helm_release.kafka[0].name}.${var.openshift_project_name}.svc.cluster.local"
    port              = 9092
  } : null
}

# Output deployment status
output "deployment_status" {
  description = "Status of deployed infrastructure components"
  value = {
    deployed_components = var.infrastructure
    namespace          = var.openshift_project_name
    postgresql_deployed = contains(var.infrastructure, "postgresql")
    kafka_deployed     = contains(var.infrastructure, "kafka")
  }
}
