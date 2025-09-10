#!/bin/bash
# Multi-Service Deployment Script using Bitnami Helm Charts
# Author: Automated Service Deployment
# Date: $(date)
# Description: Complete automation script for deploying PostgreSQL or Kafka in Kubernetes

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
NAMESPACE=""
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

print_header() {
    echo -e "${PURPLE}[HEADER]${NC} $1"
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

# Function to create PostgreSQL values file
create_postgresql_values_file() {
    print_status "Creating PostgreSQL values file..."
    
    cat > ${SERVICE_TYPE}-values.yaml << EOF
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
    
    print_success "PostgreSQL values file created: ${SERVICE_TYPE}-values.yaml"
}

# Function to create Kafka values file
create_kafka_values_file() {
    print_status "Creating Kafka values file..."
    
    cat > ${SERVICE_TYPE}-values.yaml << EOF
# Kafka Configuration
replicaCount: $KAFKA_REPLICA_COUNT

# Authentication configuration
auth:
  clientProtocol: sasl
  interBrokerProtocol: sasl
  sasl:
    mechanisms: plain
    users:
      - $KAFKA_USERNAME
    passwords:
      - $KAFKA_PASSWORD

# ZooKeeper configuration
zookeeper:
  enabled: $($KAFKA_ENABLE_KRAFT && echo "false" || echo "true")
  auth:
    client:
      enabled: true
      clientUser: "zookeeper"
      clientPassword: "ZookeeperPassword123"

# KRaft configuration (if enabled)
kraft:
  enabled: $KAFKA_ENABLE_KRAFT

# Persistence configuration
persistence:
  enabled: true
  size: $STORAGE_SIZE
  storageClass: "$STORAGE_CLASS"
  accessModes:
    - ReadWriteOnce

# Resources configuration
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
    client: 9092
    internal: 9093

# External access configuration (disabled by default)
externalAccess:
  enabled: false

# Metrics configuration
metrics:
  kafka:
    enabled: false
  jmx:
    enabled: false

# Log configuration
logPersistence:
  enabled: true
  size: "8Gi"
  storageClass: "$STORAGE_CLASS"
EOF
    
    print_success "Kafka values file created: ${SERVICE_TYPE}-values.yaml"
}

# Function to deploy service
deploy_service() {
    print_status "Deploying $SERVICE_TYPE using Bitnami Helm chart..."
    
    # Install service with custom values
    if helm install $RELEASE_NAME bitnami/$SERVICE_TYPE --namespace $NAMESPACE -f ${SERVICE_TYPE}-values.yaml; then
        print_success "$SERVICE_TYPE deployment initiated successfully"
    else
        print_error "Failed to deploy $SERVICE_TYPE"
        exit 1
    fi
}

# Function to wait for deployment
wait_for_deployment() {
    print_status "Waiting for $SERVICE_TYPE to be ready..."
    
    # Wait for the pods to be ready
    if [[ "$SERVICE_TYPE" == "postgresql" ]]; then
        kubectl wait --namespace $NAMESPACE \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/name=postgresql \
            --timeout=300s
    elif [[ "$SERVICE_TYPE" == "kafka" ]]; then
        kubectl wait --namespace $NAMESPACE \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/name=kafka \
            --timeout=300s
    fi
    
    print_success "$SERVICE_TYPE is ready!"
}

# Function to get PostgreSQL connection information
get_postgresql_connection_info() {
    print_status "Retrieving PostgreSQL connection information..."
    
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
}

# Function to get Kafka connection information
get_kafka_connection_info() {
    print_status "Retrieving Kafka connection information..."
    
    # Get passwords
    if kubectl get secret --namespace $NAMESPACE $RELEASE_NAME-user-passwords &> /dev/null; then
        KAFKA_PASSWORD_FROM_SECRET=$(kubectl get secret --namespace $NAMESPACE $RELEASE_NAME-user-passwords -o jsonpath="{.data.client-passwords}" | base64 -d | cut -d, -f1)
    else
        KAFKA_PASSWORD_FROM_SECRET=$KAFKA_PASSWORD
    fi
    
    echo
    print_success "Kafka deployed successfully!"
    echo
    echo "=== CONNECTION INFORMATION ==="
    echo "Release Name: $RELEASE_NAME"
    echo "Namespace: $NAMESPACE"
    echo "Service: $RELEASE_NAME.$NAMESPACE.svc.cluster.local"
    echo "Port: 9092"
    echo "Replica Count: $KAFKA_REPLICA_COUNT"
    echo "KRaft Mode: $KAFKA_ENABLE_KRAFT"
    echo
    echo "=== CREDENTIALS ==="
    echo "Username: $KAFKA_USERNAME"
    echo "Password: $KAFKA_PASSWORD_FROM_SECRET"
    echo
    echo "=== CONNECTION COMMANDS ==="
    echo
    echo "1. Connect from inside cluster:"
    echo "kubectl run ${RELEASE_NAME}-client --restart='Never' -it --rm \\"
    echo "  --namespace $NAMESPACE \\"
    echo "  --image docker.io/bitnami/kafka:latest \\"
    echo "  -- kafka-console-producer.sh \\"
    echo "  --bootstrap-server $RELEASE_NAME.$NAMESPACE.svc.cluster.local:9092 \\"
    echo "  --topic test-topic"
    echo
    echo "2. Consumer example:"
    echo "kubectl run ${RELEASE_NAME}-consumer --restart='Never' -it --rm \\"
    echo "  --namespace $NAMESPACE \\"
    echo "  --image docker.io/bitnami/kafka:latest \\"
    echo "  -- kafka-console-consumer.sh \\"
    echo "  --bootstrap-server $RELEASE_NAME.$NAMESPACE.svc.cluster.local:9092 \\"
    echo "  --topic test-topic \\"
    echo "  --from-beginning"
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
}

# Function to create PostgreSQL connection script
create_postgresql_connection_script() {
    print_status "Creating PostgreSQL connection helper script..."
    
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
    print_success "PostgreSQL connection script created: connect-postgresql.sh"
}

# Function to create Kafka connection script
create_kafka_connection_script() {
    print_status "Creating Kafka connection helper script..."
    
    cat > connect-kafka.sh << EOF
#!/bin/bash
# Kafka Connection Helper Script
RELEASE_NAME="$RELEASE_NAME"
NAMESPACE="$NAMESPACE"
KAFKA_USERNAME="$KAFKA_USERNAME"

echo "Choose Kafka operation:"
echo "1. Create a topic"
echo "2. Producer (send messages)"
echo "3. Consumer (receive messages)"
echo "4. List topics"
echo "5. Port forward for external access"
echo "6. Show connection info"

read -p "Enter choice (1-6): " choice

case \$choice in
    1)
        read -p "Enter topic name: " topic_name
        kubectl run \${RELEASE_NAME}-admin --restart='Never' -it --rm \\
            --namespace \$NAMESPACE \\
            --image docker.io/bitnami/kafka:latest \\
            -- kafka-topics.sh \\
            --bootstrap-server \$RELEASE_NAME.\$NAMESPACE.svc.cluster.local:9092 \\
            --create --topic \$topic_name --partitions 3 --replication-factor 1
        ;;
    2)
        read -p "Enter topic name: " topic_name
        echo "Starting producer. Type messages and press Enter to send. Use Ctrl+C to exit."
        kubectl run \${RELEASE_NAME}-producer --restart='Never' -it --rm \\
            --namespace \$NAMESPACE \\
            --image docker.io/bitnami/kafka:latest \\
            -- kafka-console-producer.sh \\
            --bootstrap-server \$RELEASE_NAME.\$NAMESPACE.svc.cluster.local:9092 \\
            --topic \$topic_name
        ;;
    3)
        read -p "Enter topic name: " topic_name
        echo "Starting consumer. Use Ctrl+C to exit."
        kubectl run \${RELEASE_NAME}-consumer --restart='Never' -it --rm \\
            --namespace \$NAMESPACE \\
            --image docker.io/bitnami/kafka:latest \\
            -- kafka-console-consumer.sh \\
            --bootstrap-server \$RELEASE_NAME.\$NAMESPACE.svc.cluster.local:9092 \\
            --topic \$topic_name \\
            --from-beginning
        ;;
    4)
        kubectl run \${RELEASE_NAME}-admin --restart='Never' -it --rm \\
            --namespace \$NAMESPACE \\
            --image docker.io/bitnami/kafka:latest \\
            -- kafka-topics.sh \\
            --bootstrap-server \$RELEASE_NAME.\$NAMESPACE.svc.cluster.local:9092 \\
            --list
        ;;
    5)
        echo "Setting up port forward..."
        echo "Kafka will be available at localhost:9092"
        echo "Use Ctrl+C to stop port forwarding"
        kubectl port-forward --namespace \$NAMESPACE svc/\$RELEASE_NAME 9092:9092
        ;;
    6)
        echo "=== CONNECTION INFORMATION ==="
        echo "Service: \$RELEASE_NAME.\$NAMESPACE.svc.cluster.local:9092"
        echo "Username: $KAFKA_USERNAME"
        echo "Replica Count: $KAFKA_REPLICA_COUNT"
        echo "KRaft Mode: $KAFKA_ENABLE_KRAFT"
        ;;
    *)
        echo "Invalid choice"
        ;;
esac
EOF
    chmod +x connect-kafka.sh
    print_success "Kafka connection script created: connect-kafka.sh"
}

# Function to cleanup files
cleanup_files() {
    read -p "Do you want to clean up temporary files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f ${SERVICE_TYPE}-values.yaml
        print_success "Temporary files cleaned up"
    fi
}

# Function to get user input for service type
get_service_type() {
    echo
    print_header "=== SERVICE SELECTION ==="
    echo "Which service would you like to deploy?"
    echo "1. PostgreSQL"
    echo "2. Kafka"
    echo
    
    while true; do
        read -p "Enter your choice (1-2): " choice
        case $choice in
            1)
                SERVICE_TYPE="postgresql"
                NAMESPACE="database"
                RELEASE_NAME="my-postgresql"
                break
                ;;
            2)
                SERVICE_TYPE="kafka"
                NAMESPACE="messaging"
                RELEASE_NAME="my-kafka"
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
    
    print_success "Selected service: $SERVICE_TYPE"
}

# Function to get user configuration
get_user_configuration() {
    echo
    print_header "=== CONFIGURATION ==="
    
    # Common configuration
    read -p "Release name [$RELEASE_NAME]: " input_release_name
    RELEASE_NAME=${input_release_name:-$RELEASE_NAME}
    
    read -p "Namespace [$NAMESPACE]: " input_namespace
    NAMESPACE=${input_namespace:-$NAMESPACE}
    
    read -p "Storage size [$STORAGE_SIZE]: " input_storage_size
    STORAGE_SIZE=${input_storage_size:-$STORAGE_SIZE}
    
    read -p "Storage class [$STORAGE_CLASS]: " input_storage_class
    STORAGE_CLASS=${input_storage_class:-$STORAGE_CLASS}
    
    # Service-specific configuration
    if [[ "$SERVICE_TYPE" == "postgresql" ]]; then
        echo
        print_header "PostgreSQL Configuration:"
        read -p "Database name [$DB_NAME]: " input_db_name
        DB_NAME=${input_db_name:-$DB_NAME}
        
        read -p "Database username [$DB_USERNAME]: " input_db_username
        DB_USERNAME=${input_db_username:-$DB_USERNAME}
        
        read -s -p "Admin password [$POSTGRES_ADMIN_PASSWORD]: " input_admin_password
        echo
        POSTGRES_ADMIN_PASSWORD=${input_admin_password:-$POSTGRES_ADMIN_PASSWORD}
        
        read -s -p "User password [$DB_USER_PASSWORD]: " input_user_password
        echo
        DB_USER_PASSWORD=${input_user_password:-$DB_USER_PASSWORD}
        
    elif [[ "$SERVICE_TYPE" == "kafka" ]]; then
        echo
        print_header "Kafka Configuration:"
        read -p "Replica count [$KAFKA_REPLICA_COUNT]: " input_replica_count
        KAFKA_REPLICA_COUNT=${input_replica_count:-$KAFKA_REPLICA_COUNT}
        
        read -p "Enable KRaft mode? (y/N): " enable_kraft
        if [[ $enable_kraft =~ ^[Yy]$ ]]; then
            KAFKA_ENABLE_KRAFT=true
        else
            KAFKA_ENABLE_KRAFT=false
        fi
        
        read -p "Kafka username [$KAFKA_USERNAME]: " input_kafka_username
        KAFKA_USERNAME=${input_kafka_username:-$KAFKA_USERNAME}
        
        read -s -p "Kafka password [$KAFKA_PASSWORD]: " input_kafka_password
        echo
        KAFKA_PASSWORD=${input_kafka_password:-$KAFKA_PASSWORD}
    fi
}

# Function to show configuration summary
show_configuration_summary() {
    echo
    print_header "=== DEPLOYMENT SUMMARY ==="
    echo "Service Type: $SERVICE_TYPE"
    echo "Release Name: $RELEASE_NAME"
    echo "Namespace: $NAMESPACE"
    echo "Storage Size: $STORAGE_SIZE"
    echo "Storage Class: $STORAGE_CLASS"
    
    if [[ "$SERVICE_TYPE" == "postgresql" ]]; then
        echo "Database Name: $DB_NAME"
        echo "Database User: $DB_USERNAME"
    elif [[ "$SERVICE_TYPE" == "kafka" ]]; then
        echo "Replica Count: $KAFKA_REPLICA_COUNT"
        echo "KRaft Mode: $KAFKA_ENABLE_KRAFT"
        echo "Kafka Username: $KAFKA_USERNAME"
    fi
    
    echo "Memory Limit: $MEMORY_LIMIT"
    echo "CPU Limit: $CPU_LIMIT"
    echo
}

# Main execution function
main() {
    echo "=========================================="
    echo "   Multi-Service Kubernetes Deployment"
    echo "   Using Bitnami Helm Charts"
    echo "=========================================="
    echo
    
    # Get service type from user
    get_service_type
    
    # Get configuration from user
    get_user_configuration
    
    # Show configuration summary
    show_configuration_summary
    
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
    
    # Create service-specific values file
    if [[ "$SERVICE_TYPE" == "postgresql" ]]; then
        create_postgresql_values_file
    elif [[ "$SERVICE_TYPE" == "kafka" ]]; then
        create_kafka_values_file
    fi
    
    deploy_service
    wait_for_deployment
    verify_deployment
    
    # Get connection information
    if [[ "$SERVICE_TYPE" == "postgresql" ]]; then
        get_postgresql_connection_info
        create_postgresql_connection_script
    elif [[ "$SERVICE_TYPE" == "kafka" ]]; then
        get_kafka_connection_info
        create_kafka_connection_script
    fi
    
    cleanup_files
    
    echo
    print_success "$SERVICE_TYPE deployment completed successfully!"
    
    if [[ "$SERVICE_TYPE" == "postgresql" ]]; then
        print_status "Run './connect-postgresql.sh' to connect to your database"
    elif [[ "$SERVICE_TYPE" == "kafka" ]]; then
        print_status "Run './connect-kafka.sh' to interact with your Kafka cluster"
    fi
}

# Handle script interruption
trap 'print_error "Script interrupted"; exit 1' INT

# Run main function
main "$@"
