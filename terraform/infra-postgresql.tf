
# resource "random_password" "postgresql_password" {
#   length  = 16
#   upper   = true
#   lower   = true
#   numeric = true
#   special = false

#   min_upper   = 1
#   min_lower   = 1
#   min_numeric = 1
# }

# resource "null_resource" "check_cluster_access" {
#   provisioner "local-exec" {
#     command = <<EOT
# kubectl cluster-info || { echo "ERROR: Cannot connect to OpenShift cluster"; exit 1; }
# EOT
#   }
# }

# resource "null_resource" "apply_disk_rules" {
#   provisioner "local-exec" {
#     command = "kubectl apply -f https://raw.githubusercontent.com/andyzhangx/demo/refs/heads/master/aks/download-v6-disk-rules.yaml"
#   }
# }

# resource "null_resource" "install_postgresql" {
#   count = contains(var.infrastructure, "postgresql") ? 1 : 0

#   provisioner "local-exec" {
#     command = join(" && ", [
#       "helm repo add bitnami https://charts.bitnami.com/bitnami",
#       "helm repo update",
#       format(
#         "helm upgrade --install postgresql bitnami/postgresql --version 16.4.16 --namespace devops-openshift --wait --timeout=10m --set auth.enablePostgresUser=true,auth.username='%s',auth.password='%s',auth.database='%s',primary.persistence.storageClass=%s,primary.persistence.size=%s",
#         var.postgresql_username,
#         random_password.postgresql_password.result,
#         var.postgresql_database,
#         var.persistence_storage_class,
#         var.persistence_storage_size
#       )
#     ])
#   }

#   depends_on = [null_resource.apply_disk_rules]
# }


# #############################
# # Retrieve the PostgreSQL secret
# #############################

# resource "null_resource" "read_postgresql_secret" {
#   provisioner "local-exec" {
#     command = <<EOF
# sleep 10
# kubectl get secret postgresql -n ${lower(var.openshift_project_name)} -o json
# EOF
#   }

#   depends_on = [null_resource.install_postgresql]
# }

#############################
# Locals to process the secret output
# #############################
# locals {
# #   # secret_json_matches = length(azureakscommand_invoke.read_postgresql_secret) > 0 ? regexall("\\{[\\s\\S]*\\}", azureakscommand_invoke.read_postgresql_secret[0].output) : []

# #   secret_json = length(local.secret_json_matches) > 0 ? trimspace(local.secret_json_matches[0]) : ""

# #   postgresql_secret_map = local.secret_json != "" ? jsondecode(local.secret_json) : tomap({})

# #   #postgresql_password = try(
# #   #  base64decode(local.postgresql_secret_map.data["postgres-password"]),
# #   #  ""
# #   #)

#   postgresql_password = random_password.postgresql_password.result

#   postgresql_host     = format("postgresql.%s.svc.cluster.local", lower(var.openshift_project_name))
#   postgresql_port     = "5432"
#   postgresql_username = var.postgresql_username
#   postgresql_database = var.postgresql_database
# }

# # Load the secret JSON back into Terraform
# data "local_file" "postgresql_secret" {
#   filename    = "${path.module}/postgresql-secret.json"
#   depends_on  = [null_resource.read_postgresql_secret]
# }

resource "random_password" "postgresql_password" {
  length  = 16
  upper   = true
  lower   = true
  numeric = true
  special = false

  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

resource "null_resource" "check_cluster_access" {
  provisioner "local-exec" {
    command = <<EOT
kubectl cluster-info || { echo "ERROR: Cannot connect to OpenShift cluster"; exit 1; }
EOT
  }
}

resource "null_resource" "apply_disk_rules" {
  provisioner "local-exec" {
    command = "kubectl apply -f https://raw.githubusercontent.com/andyzhangx/demo/refs/heads/master/aks/download-v6-disk-rules.yaml"
  }
}

resource "null_resource" "install_postgresql" {
  count = contains(var.infrastructure, "postgresql") ? 1 : 0

   triggers = {
    namespace = var.openshift_project_name
  }
  
  provisioner "local-exec" {
    command = join(" && ", [
      "helm repo add bitnami https://charts.bitnami.com/bitnami",
      "helm repo update",
      format(
        "helm upgrade --install postgresql bitnami/postgresql --version 16.4.16 --namespace %s --wait --timeout=10m --set auth.enablePostgresUser=true,auth.postgresPassword='%s',auth.database='%s',primary.persistence.storageClass=\"%s\",primary.persistence.size=\"%s\"",
        var.openshift_project_name,
        random_password.postgresql_password.result,
        var.postgresql_database,
        var.persistence_storage_class,
        var.persistence_storage_size
      )
    ])
  }

  # Destruction-time provisioner
  provisioner "local-exec" {
    when    = destroy
    # Reference the stored trigger value using 'self'
    command = "helm uninstall postgresql --namespace ${self.triggers.namespace}"
  }

  depends_on = [null_resource.apply_disk_rules]
}

# Capture the secret from OpenShift
resource "null_resource" "read_postgresql_secret" {
  provisioner "local-exec" {
    command = <<EOT
kubectl get secret postgresql -n ${var.openshift_project_name} -o json > postgresql-secret.json
EOT
  }
  triggers = {
    always_run = timestamp()
  }

  depends_on = [null_resource.install_postgresql]
}

# Load the secret JSON back into Terraform
data "local_file" "postgresql_secret" {
  filename   = "${path.module}/postgresql-secret.json"
  depends_on = [null_resource.read_postgresql_secret]
}

locals {
  # Parse JSON into map
  postgresql_secret_map = jsondecode(data.local_file.postgresql_secret.content)

  # Decode password from base64
  postgresql_password   = base64decode(local.postgresql_secret_map.data["postgres-password"])

  # Connection details
  postgresql_host       = format("postgresql.%s.svc.cluster.local", lower(var.openshift_project_name))
  postgresql_port       = "5432"
  postgresql_username   = var.postgresql_username
  postgresql_database   = var.postgresql_database
}

output "postgresql_connection_password" {
  description = "The password for the 'postgres' user."
  value       = local.postgresql_password
  sensitive   = true # This hides it in logs but shows it with 'terraform output'
}