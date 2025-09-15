# ===========================================
# Target OpenShift Namespace / Project
# ===========================================
# All resources (PostgreSQL, Kafka, etc.) will be deployed inside this namespace.
openshift_project_name = "devops-openshift"

# ===========================================
# Infrastructure Components to Deploy
# ===========================================
# You can choose what to deploy by setting this list:
#   ["postgresql"]       → Deploy only PostgreSQL
#   ["kafka"]            → Deploy only Kafka
#   ["postgresql", "kafka"] → Deploy both PostgreSQL and Kafka
infrastructure = ["postgresql", "kafka"]

# ===========================================
# PostgreSQL Configuration
# ===========================================
# Username for the PostgreSQL superuser
postgresql_username = "postgres"

# Default database to create inside PostgreSQL
postgresql_database = "mydatabase"

# ===========================================
# Persistent Storage Configuration
# ===========================================
# StorageClass to use for PersistentVolumeClaims (PVCs)
# Make sure this matches your OpenShift cluster storage class (e.g., managed-csi)
persistence_storage_class = "managed-csi"

# Size of the PersistentVolume to allocate for each component
persistence_storage_size  = "5Gi"
