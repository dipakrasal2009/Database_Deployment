#!/bin/bash

# PostgreSQL Deployment Script using Bitnami Helm Chart
# Author: Automated PostgreSQL Deployment
# Date: $(date)
# Description: Complete automation script for deploying PostgreSQL in Kubernetes

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration Variables (Modify as needed)
RELEASE_NAME="my-postgresql"
NAMESPACE="database"
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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm first."
        exit 1
    fi
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_success "All prerequisites satisfied"
}

# Function to add Bitnami Helm repository
# Function to add Bitnami Helm repository
setup_helm_repo() {
    print_status "Setting up Bitnami Helm repository..."

    # Check if bitnami repo exists
    if helm repo list | awk '{print $1}' | grep -q "^bitnami$"; then
        print_warning "Bitnami repository already exists, skipping add"
    else
        helm repo add bitnami https://charts.bitnami.com/bitnami
    fi

    # Always update
    helm repo update

    print_success "Bitnami repository is ready"
}

# Function to create namespace
create_namespace() {
    print_status "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_warning "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace $NAMESPACE
        print_success "Namespace $NAMESPACE created"
    fi
}

# Function to check if release already exists
check_existing_release() {
    if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
        print_warning "Release $RELEASE_NAME already exists in namespace $NAMESPACE"
        read -p "Do you want to uninstall the existing release? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Uninstalling existing release..."
            helm uninstall $RELEASE_NAME --namespace $NAMESPACE
            
            # Wait for cleanup
            print_status "Waiting for cleanup..."
            sleep 10
            
            # Ask about PVC cleanup
            read -p "Do you want to delete existing persistent volume claims (THIS WILL DELETE DATA)? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                kubectl delete pvc -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME --ignore-not-found=true
                print_warning "Persistent volume claims deleted"
            fi
            
            print_success "Existing release uninstalled"
        else
            print_error "Cannot proceed with existing release. Exiting."
            exit 1
        fi
    fi
}

# Function to create values file
create_values_file() {
    print_status "Creating PostgreSQL values file..."
    
    cat > postgres-values.yaml << EOF
# PostgreSQL Configuration
auth:
  postgresPassword: "$POSTGRES_ADMIN_PASSWORD"
  username: "$DB_USERNAME"
  password: "$DB_USER_PASSWORD"
  database: "$DB_NAME"

# Primary PostgreSQL configuration
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

# Service configuration
service:
  type: ClusterIP
  ports:
    postgresql: 5432

# Metrics configuration (optional)
metrics:
  enabled: false
  
# Security context
primary:
  podSecurityContext:
    enabled: true
    fsGroup: 1001
  containerSecurityContext:
    enabled: true
    runAsUser: 1001
    runAsNonRoot: true
EOF

    print_success "Values file created: postgres-values.yaml"
}

# Function to deploy PostgreSQL
deploy_postgresql() {
    print_status "Deploying PostgreSQL using Bitnami Helm chart..."
    
    # Install PostgreSQL with custom values
    if helm install $RELEASE_NAME bitnami/postgresql --namespace $NAMESPACE -f postgres-values.yaml; then
        print_success "PostgreSQL deployment initiated successfully"
    else
        print_error "Failed to deploy PostgreSQL"
        exit 1
    fi
}

# Function to wait for deployment
wait_for_deployment() {
    print_status "Waiting for PostgreSQL to be ready..."
    
    # Wait for the StatefulSet to be ready
    kubectl wait --namespace $NAMESPACE \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=postgresql \
        --timeout=300s
    
    print_success "PostgreSQL is ready!"
}

# Function to get connection information
get_connection_info() {
    print_status "Retrieving connection information..."
    
    # Get passwords
    POSTGRES_PASSWORD=$(kubectl get secret --namespace $NAMESPACE $RELEASE_NAME -o jsonpath="{.data.postgres-password}" | base64 -d)
    USER_PASSWORD=$(kubectl get secret --namespace $NAMESPACE $RELEASE_NAME -o jsonpath="{.data.password}" | base64 -d)
    
    echo
    print_success "PostgreSQL deployed successfully!"
    echo
    echo "=== CONNECTION INFORMATION ==="
    echo "Release Name: $RELEASE_NAME"
    echo "Namespace: $NAMESPACE"
    echo "Service: $RELEASE_NAME.$NAMESPACE.svc.cluster.local"
    echo "Port: 5432"
    echo
    echo "=== CREDENTIALS ==="
    echo "Admin User: postgres"
    echo "Admin Password: $POSTGRES_PASSWORD"
    echo "Database User: $DB_USERNAME"
    echo "User Password: $USER_PASSWORD"
    echo "Database Name: $DB_NAME"
    echo
    echo "=== CONNECTION COMMANDS ==="
    echo
    echo "1. Connect from inside cluster:"
    echo "kubectl run ${RELEASE_NAME}-client --rm --tty -i --restart='Never' \\"
    echo "  --namespace $NAMESPACE \\"
    echo "  --image docker.io/bitnami/postgresql:17.6.0-debian-12-r4 \\"
    echo "  --env=\"PGPASSWORD=$POSTGRES_PASSWORD\" \\"
    echo "  --command -- psql --host $RELEASE_NAME -U postgres -d $DB_NAME -p 5432"
    echo
    echo "2. Port forward for external access:"
    echo "kubectl port-forward --namespace $NAMESPACE svc/$RELEASE_NAME 5432:5432 &"
    echo "PGPASSWORD=\"$POSTGRES_PASSWORD\" psql --host 127.0.0.1 -U postgres -d $DB_NAME -p 5432"
    echo
    echo "3. Connect with custom user:"
    echo "PGPASSWORD=\"$USER_PASSWORD\" psql --host 127.0.0.1 -U $DB_USERNAME -d $DB_NAME -p 5432"
    echo
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    echo
    echo "=== KUBERNETES RESOURCES ==="
    kubectl get all -n $NAMESPACE
    echo
    echo "=== PERSISTENT VOLUME CLAIMS ==="
    kubectl get pvc -n $NAMESPACE
    echo
    echo "=== SECRETS ==="
    kubectl get secrets -n $NAMESPACE
    echo
}

# Function to create connection script
create_connection_script() {
    print_status "Creating connection helper script..."
    
    cat > connect-postgresql.sh << EOF
#!/bin/bash
# PostgreSQL Connection Helper Script

RELEASE_NAME="$RELEASE_NAME"
NAMESPACE="$NAMESPACE"
DB_NAME="$DB_NAME"
DB_USERNAME="$DB_USERNAME"

# Get passwords from secret
POSTGRES_PASSWORD=\$(kubectl get secret --namespace \$NAMESPACE \$RELEASE_NAME -o jsonpath="{.data.postgres-password}" | base64 -d)
USER_PASSWORD=\$(kubectl get secret --namespace \$NAMESPACE \$RELEASE_NAME -o jsonpath="{.data.password}" | base64 -d)

echo "Choose connection method:"
echo "1. Connect as admin (postgres user)"
echo "2. Connect as custom user ($DB_USERNAME)"
echo "3. Port forward for external access"
echo "4. Show all connection info"
read -p "Enter choice (1-4): " choice

case \$choice in
    1)
        echo "Connecting as postgres user..."
        kubectl run \${RELEASE_NAME}-client --rm --tty -i --restart='Never' \\
            --namespace \$NAMESPACE \\
            --image docker.io/bitnami/postgresql:17.6.0-debian-12-r4 \\
            --env="PGPASSWORD=\$POSTGRES_PASSWORD" \\
            --command -- psql --host \$RELEASE_NAME -U postgres -d \$DB_NAME -p 5432
        ;;
    2)
        echo "Connecting as $DB_USERNAME..."
        kubectl run \${RELEASE_NAME}-client --rm --tty -i --restart='Never' \\
            --namespace \$NAMESPACE \\
            --image docker.io/bitnami/postgresql:17.6.0-debian-12-r4 \\
            --env="PGPASSWORD=\$USER_PASSWORD" \\
            --command -- psql --host \$RELEASE_NAME -U \$DB_USERNAME -d \$DB_NAME -p 5432
        ;;
    3)
        echo "Setting up port forward..."
        echo "PostgreSQL will be available at localhost:5432"
        echo "Use Ctrl+C to stop port forwarding"
        echo
        echo "Connection commands:"
        echo "Admin: PGPASSWORD=\"\$POSTGRES_PASSWORD\" psql --host 127.0.0.1 -U postgres -d $DB_NAME -p 5432"
        echo "User: PGPASSWORD=\"\$USER_PASSWORD\" psql --host 127.0.0.1 -U $DB_USERNAME -d $DB_NAME -p 5432"
        echo
        kubectl port-forward --namespace \$NAMESPACE svc/\$RELEASE_NAME 5432:5432
        ;;
    4)
        echo "=== CONNECTION INFORMATION ==="
        echo "Service: \$RELEASE_NAME.\$NAMESPACE.svc.cluster.local:5432"
        echo "Admin User: postgres"
        echo "Admin Password: \$POSTGRES_PASSWORD"
        echo "Database User: $DB_USERNAME"
        echo "User Password: \$USER_PASSWORD"
        echo "Database Name: $DB_NAME"
        ;;
    *)
        echo "Invalid choice"
        ;;
esac
EOF

    chmod +x connect-postgresql.sh
    print_success "Connection script created: connect-postgresql.sh"
}

# Function to cleanup (optional)
cleanup_files() {
    read -p "Do you want to clean up temporary files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f postgres-values.yaml
        print_success "Temporary files cleaned up"
    fi
}

# Main execution function
main() {
    echo "=========================================="
    echo "   PostgreSQL Kubernetes Deployment"
    echo "   Using Bitnami Helm Chart"
    echo "=========================================="
    echo
    
    # Show configuration
    echo "=== DEPLOYMENT CONFIGURATION ==="
    echo "Release Name: $RELEASE_NAME"
    echo "Namespace: $NAMESPACE"
    echo "Storage Size: $STORAGE_SIZE"
    echo "Storage Class: $STORAGE_CLASS"
    echo "Database Name: $DB_NAME"
    echo "Database User: $DB_USERNAME"
    echo "Memory Limit: $MEMORY_LIMIT"
    echo "CPU Limit: $CPU_LIMIT"
    echo
    
    read -p "Proceed with deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled"
        exit 0
    fi
    
    # Execute deployment steps
    check_prerequisites
    setup_helm_repo
    create_namespace
    check_existing_release
    create_values_file
    deploy_postgresql
    wait_for_deployment
    verify_deployment
    get_connection_info
    create_connection_script
    cleanup_files
    
    echo
    print_success "PostgreSQL deployment completed successfully!"
    print_status "Run './connect-postgresql.sh' to connect to your database"
}

# Handle script interruption
trap 'print_error "Script interrupted"; exit 1' INT

# Run main function
main "$@"
