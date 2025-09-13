# Target OpenShift project/namespace
openshift_project_name = "devops-openshift"

# List of infrastructure components to deploy
# Include "postgresql" if you want to install PostgreSQL
infrastructure = ["postgresql"]

# PostgreSQL configuration
postgresql_username = "postgres"
postgresql_database = "mydatabase"

# Persistent storage settings
persistence_storage_class = "managed-csi"
persistence_storage_size  = "5Gi"