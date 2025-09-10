#!/bin/bash
# Multi-Service Deployment Script using Bitnami Helm Charts on OpenShift
# Author: Automated Service Deployment
# Date: $(date)
# Description: Automates PostgreSQL or Kafka deployment on OpenShift using Helm and oc

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Global Configuration Variables
RELEASE_NAME=""
PROJECT=""
SERVICE_TYPE=""

# PostgreSQL Configuration
POSTGRES_ADMIN_PASSWORD="AdminPassword123"
DB_USERNAME="myuser"
DB_USER_PASSWORD="UserPassword123"
DB_NAME="mydatabase"

# Kafka Configuration
KAFKA_USERNAME="kafka-user"
KAFKA_PASSWORD="KafkaPassword123"
KAFKA_REPLICA_COUNT=3
KAFKA_ENABLE_KRAFT=true

# Common Configuration
STORAGE_SIZE="10Gi"
STORAGE_CLASS="standard"
MEMORY_LIMIT="1Gi"
CPU_LIMIT="500m"
MEMORY_REQUEST="512Mi"
CPU_REQUEST="250m"

# Print helpers
print_status()  { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
print_header()  { echo -e "${PURPLE}[HEADER]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
  print_status "Checking prerequisites..."
  if ! command -v oc &> /dev/null; then
    print_error "oc CLI is not installed. Please install the OpenShift CLI (oc)."
    exit 1
  fi
  if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed. Please install Helm 3."
    exit 1
  fi
  if ! oc whoami &> /dev/null; then
    print_error "Not logged in to OpenShift. Run 'oc login' first."
    exit 1
  fi
  print_success "All prerequisites satisfied"
}

# Add Bitnami Helm repo
setup_helm_repo() {
  print_status "Setting up Bitnami Helm repository..."
  if helm repo list | awk '{print $1}' | grep -q "^bitnami$"; then
    print_warning "Bitnami repo exists, skipping add"
  else
    helm repo add bitnami https://charts.bitnami.com/bitnami
  fi
  helm repo update
  print_success "Bitnami repository ready"
}

# Create or switch to OpenShift project
create_project() {
  print_status "Using project: $PROJECT"
  if oc get project "$PROJECT" &> /dev/null; then
    oc project "$PROJECT"
    print_warning "Switched to existing project $PROJECT"
  else
    oc new-project "$PROJECT"
    print_success "Created and switched to project $PROJECT"
  fi
}

# Uninstall existing release
check_existing_release() {
  if helm list -n "$PROJECT" | grep -qw "$RELEASE_NAME"; then
    print_warning "Release $RELEASE_NAME exists in project $PROJECT"
    read -p "Uninstall existing release? (y/N): " -n1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      print_status "Uninstalling $RELEASE_NAME..."
      helm uninstall "$RELEASE_NAME" -n "$PROJECT"
      sleep 10
      read -p "Delete PVCs? (THIS WILL DELETE DATA) (y/N): " -n1 -r; echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        oc delete pvc -n "$PROJECT" -l app.kubernetes.io/instance="$RELEASE_NAME" --ignore-not-found
        print_warning "PVCs deleted"
      fi
      print_success "Existing release removed"
    else
      print_error "Cannot proceed. Exiting."
      exit 1
    fi
  fi
}

# Generate values file for PostgreSQL
create_postgresql_values_file() {
  print_status "Creating PostgreSQL values..."
  cat > "${SERVICE_TYPE}-values.yaml" <<EOF
auth:
  postgresPassword: "$POSTGRES_ADMIN_PASSWORD"
  username: "$DB_USERNAME"
  password: "$DB_USER_PASSWORD"
  database: "$DB_NAME"
primary:
  persistence:
    enabled: true
    size: $STORAGE_SIZE
    storageClass: "$STORAGE_CLASS"
    accessModes: ["ReadWriteOnce"]
  resources:
    limits:   { memory: "$MEMORY_LIMIT", cpu: "$CPU_LIMIT" }
    requests: { memory: "$MEMORY_REQUEST", cpu: "$CPU_REQUEST" }
service:
  type: ClusterIP
  ports: { postgresql: 5432 }
metrics: { enabled: false }
primary:
  podSecurityContext:      { enabled: true, fsGroup: 1001 }
  containerSecurityContext: { enabled: true, runAsUser: 1001, runAsNonRoot: true }
EOF
  print_success "PostgreSQL values file: ${SERVICE_TYPE}-values.yaml"
}

# Generate values file for Kafka
create_kafka_values_file() {
  print_status "Creating Kafka values..."
  cat > "${SERVICE_TYPE}-values.yaml" <<EOF
replicaCount: $KAFKA_REPLICA_COUNT
auth:
  clientProtocol: sasl
  interBrokerProtocol: sasl
  sasl:
    mechanisms: [plain]
    users:      ["$KAFKA_USERNAME"]
    passwords:  ["$KAFKA_PASSWORD"]
zookeeper:
  enabled: $([ "$KAFKA_ENABLE_KRAFT" = true ] && echo false || echo true)
  auth:
    client:
      enabled: true
      clientUser: "zookeeper"
      clientPassword: "ZookeeperPassword123"
kraft: { enabled: $KAFKA_ENABLE_KRAFT }
persistence:
  enabled: true
  size: $STORAGE_SIZE
  storageClass: "$STORAGE_CLASS"
  accessModes: ["ReadWriteOnce"]
resources:
  limits:   { memory: "$MEMORY_LIMIT", cpu: "$CPU_LIMIT" }
  requests: { memory: "$MEMORY_REQUEST", cpu: "$CPU_REQUEST" }
service:
  type: ClusterIP
  ports: { client: 9092, internal: 9093 }
externalAccess: { enabled: false }
metrics:
  kafka: { enabled: false }
  jmx:   { enabled: false }
logPersistence:
  enabled: true
  size: "8Gi"
  storageClass: "$STORAGE_CLASS"
EOF
  print_success "Kafka values file: ${SERVICE_TYPE}-values.yaml"
}

# Deploy selected service
deploy_service() {
  print_status "Deploying $SERVICE_TYPE..."
  helm install "$RELEASE_NAME" bitnami/"$SERVICE_TYPE" \
    --namespace "$PROJECT" -f "${SERVICE_TYPE}-values.yaml"
  print_success "$SERVICE_TYPE deploy initiated"
}

# Wait for pods ready
wait_for_deployment() {
  print_status "Waiting for $SERVICE_TYPE pods..."
  oc wait pods -n "$PROJECT" \
    -l app.kubernetes.io/name="$SERVICE_TYPE" \
    --for=condition=ready --timeout=300s
  print_success "$SERVICE_TYPE is ready"
}

# Verify resources
verify_deployment() {
  print_status "Verifying resources..."
  oc get all -n "$PROJECT"
  oc get pvc -n "$PROJECT"
  oc get secrets -n "$PROJECT"
}

# Main
main() {
  echo "======================================"
  echo " OpenShift Multi-Service Deployment"
  echo "======================================"
  get_service_type() {
    print_header "SERVICE SELECTION"
    echo "1) PostgreSQL"
    echo "2) Kafka"
    while true; do
      read -p "Choice (1-2): " c
      case $c in
        1) SERVICE_TYPE=postgresql; PROJECT=database; RELEASE_NAME=my-postgresql; break;;
        2) SERVICE_TYPE=kafka;       PROJECT=messaging; RELEASE_NAME=my-kafka;       break;;
        *) print_error "Enter 1 or 2";;
      esac
    done
    print_success "Selected: $SERVICE_TYPE"
  }
  get_service_type
  read -p "Release name [$RELEASE_NAME]: " tmp && RELEASE_NAME=${tmp:-$RELEASE_NAME}
  read -p "Project name [$PROJECT]: " tmp && PROJECT=${tmp:-$PROJECT}

  echo
  print_header "DEPLOYMENT SUMMARY"
  echo "Service:      $SERVICE_TYPE"
  echo "Release:      $RELEASE_NAME"
  echo "Project:      $PROJECT"
  echo

  read -p "Proceed? (y/N): " ans; echo
  [[ $ans =~ ^[Yy]$ ]] || { print_warning "Cancelled"; exit; }

  check_prerequisites
  setup_helm_repo
  create_project
  check_existing_release

  if [[ $SERVICE_TYPE == "postgresql" ]]; then
    create_postgresql_values_file
  else
    create_kafka_values_file
  fi

  deploy_service
  wait_for_deployment
  verify_deployment

  print_success "Deployment of $SERVICE_TYPE completed!"
}

trap 'print_error "Interrupted"; exit 1' INT
main "$@"

