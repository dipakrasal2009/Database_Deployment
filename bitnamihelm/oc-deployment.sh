#!/bin/bash

# PostgreSQL Deployment Script using Bitnami Helm Chart on OpenShift
# Author: Automated PostgreSQL Deployment
# Date: $(date)
# Description: Complete automation script for deploying PostgreSQL in OpenShift

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration Variables (Modify as needed)
RELEASE_NAME="my-postgresql"
PROJECT="database"
POSTGRES_ADMIN_PASSWORD="AdminPassword123"
DB_USERNAME="myuser"
DB_USER_PASSWORD="UserPassword123"
DB_NAME="mydatabase"
STORAGE_SIZE="10Gi"
STORAGE_CLASS="standard"  # Change based on your cluster
MEMORY_LIMIT="1Gi"
CPU_LIMIT="500m"
MEMORY_REQUEST="512Mi"
CPU_REQUEST="250m"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites: oc, helm, and login
check_prerequisites() {
    print_status "Checking prerequisites..."

    if ! command -v oc &> /dev/null; then
        print_error "oc is not installed. Please install the OpenShift CLI (oc)."
        exit 1
    fi

    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm."
        exit 1
    fi

    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift. Please run 'oc login'."
        exit 1
    fi

    print_success "All prerequisites satisfied"
}

# Add Bitnami Helm repo if missing
setup_helm_repo() {
    print_status "Configuring Bitnami Helm repository..."

    if helm repo list | awk '{print $1}' | grep -q "^bitnami$"; then
        print_warning "Bitnami repo already exists"
    else
        helm repo add bitnami https://charts.bitnami.com/bitnami
    fi

    helm repo update
    print_success "Bitnami repository ready"
}

# Create or switch to OpenShift project
setup_project() {
    print_status "Ensuring OpenShift project '$PROJECT' exists..."
    if oc get project "$PROJECT" &> /dev/null; then
        print_warning "Project '$PROJECT' already exists, switching to it"
    else
        oc new-project "$PROJECT"
        print_success "Project '$PROJECT' created"
    fi
    oc project "$PROJECT"
}

# Check for existing Helm release
check_existing_release() {
    if helm list -n "$PROJECT" | grep -q "$RELEASE_NAME"; then
        print_warning "Release '$RELEASE_NAME' already exists"
        read -p "Uninstall existing release? (y/N): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            helm uninstall "$RELEASE_NAME" -n "$PROJECT"
            print_success "Uninstalled existing release"
            sleep 10
            read -p "Delete PVCs? THIS WILL DELETE DATA (y/N): " -n 1 -r; echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                oc delete pvc -l app.kubernetes.io/instance="$RELEASE_NAME"
                print_warning "PVCs deleted"
            fi
        else
            print_error "Cannot proceed with existing release present"
            exit 1
        fi
    fi
}

# Create Helm values file
create_values_file() {
    print_status "Writing postgres-values.yaml..."
    cat > postgres-values.yaml << EOF
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
    accessModes:
      - ReadWriteOnce

  resources:
    limits:
      memory: "$MEMORY_LIMIT"
      cpu: "$CPU_LIMIT"
    requests:
      memory: "$MEMORY_REQUEST"
      cpu: "$CPU_REQUEST"

service:
  type: ClusterIP
  ports:
    postgresql: 5432

metrics:
  enabled: false

primary:
  podSecurityContext:
    enabled: true
    fsGroup: 1001
  containerSecurityContext:
    enabled: true
    runAsUser: 1001
    runAsNonRoot: true
EOF
    print_success "Values file created"
}

# Deploy PostgreSQL Helm chart
deploy_postgresql() {
    print_status "Deploying PostgreSQL Helm release..."
    helm install "$RELEASE_NAME" bitnami/postgresql \
        --namespace "$PROJECT" \
        --create-namespace \
        -f postgres-values.yaml
    print_success "Helm install command issued"
}

# Wait until pods are ready
wait_for_ready() {
    print_status "Waiting for Pods to be ready..."
    oc wait pod -l app.kubernetes.io/name=postgresql \
        --for=condition=Ready --timeout=300s
    print_success "PostgreSQL Pods are ready"
}

# Display connection info
display_connection_info() {
    ADMIN_PASS=$(oc get secret "$RELEASE_NAME" -n "$PROJECT" -o jsonpath="{.data.postgres-password}" | base64 -d)
    USER_PASS=$(oc get secret "$RELEASE_NAME" -n "$PROJECT" -o jsonpath="{.data.password}" | base64 -d)

    echo
    print_success "PostgreSQL deployed in OpenShift!"
    echo
    echo "=== CONNECTION ==="
    echo "Service: $RELEASE_NAME.$PROJECT.svc.cluster.local:5432"
    echo "Admin user: postgres"
    echo "Admin pass: $ADMIN_PASS"
    echo "App user: $DB_USERNAME"
    echo "App pass: $USER_PASS"
    echo "Database: $DB_NAME"
    echo
    echo "Inside cluster:"
    echo "  oc run pg-client --rm -i --tty --restart=Never \\"
    echo "    --image docker.io/bitnami/postgresql:17.6.0-debian-12-r4 \\"
    echo "    --env=PGPASSWORD=$ADMIN_PASS --command -- \\"
    echo "    psql --host $RELEASE_NAME -U postgres -d $DB_NAME"
    echo
    echo "Port-forward:"
    echo "  oc port-forward svc/$RELEASE_NAME 5432:5432 &"
    echo "  PGPASSWORD=$ADMIN_PASS psql -h 127.0.0.1 -U postgres -d $DB_NAME"
    echo
}

# Main
main() {
    echo "=========================================="
    echo "  PostgreSQL Deployment on OpenShift"
    echo "=========================================="
    echo
    echo "Configuration:"
    echo "  Release:     $RELEASE_NAME"
    echo "  Project:     $PROJECT"
    echo "  Storage:     $STORAGE_SIZE ($STORAGE_CLASS)"
    echo "  DB Name:     $DB_NAME"
    echo "  DB User:     $DB_USERNAME"
    echo

    read -p "Proceed? (y/N): " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Aborted"
        exit 0
    fi

    check_prerequisites
    setup_helm_repo
    setup_project
    check_existing_release
    create_values_file
    deploy_postgresql
    wait_for_ready
    display_connection_info
}

trap 'print_error "Interrupted"; exit 1' INT
main "$@"

