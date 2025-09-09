#!/bin/bash
# PostgreSQL Connection Helper Script

RELEASE_NAME="my-postgresql"
NAMESPACE="database"
DB_NAME="mydatabase"
DB_USERNAME="myuser"

# Get passwords from secret
POSTGRES_PASSWORD=$(kubectl get secret --namespace $NAMESPACE $RELEASE_NAME -o jsonpath="{.data.postgres-password}" | base64 -d)
USER_PASSWORD=$(kubectl get secret --namespace $NAMESPACE $RELEASE_NAME -o jsonpath="{.data.password}" | base64 -d)

echo "Choose connection method:"
echo "1. Connect as admin (postgres user)"
echo "2. Connect as custom user (myuser)"
echo "3. Port forward for external access"
echo "4. Show all connection info"
read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo "Connecting as postgres user..."
        kubectl run ${RELEASE_NAME}-client --rm --tty -i --restart='Never' \
            --namespace $NAMESPACE \
            --image docker.io/bitnami/postgresql:17.6.0-debian-12-r4 \
            --env="PGPASSWORD=$POSTGRES_PASSWORD" \
            --command -- psql --host $RELEASE_NAME -U postgres -d $DB_NAME -p 5432
        ;;
    2)
        echo "Connecting as myuser..."
        kubectl run ${RELEASE_NAME}-client --rm --tty -i --restart='Never' \
            --namespace $NAMESPACE \
            --image docker.io/bitnami/postgresql:17.6.0-debian-12-r4 \
            --env="PGPASSWORD=$USER_PASSWORD" \
            --command -- psql --host $RELEASE_NAME -U $DB_USERNAME -d $DB_NAME -p 5432
        ;;
    3)
        echo "Setting up port forward..."
        echo "PostgreSQL will be available at localhost:5432"
        echo "Use Ctrl+C to stop port forwarding"
        echo
        echo "Connection commands:"
        echo "Admin: PGPASSWORD=\"$POSTGRES_PASSWORD\" psql --host 127.0.0.1 -U postgres -d mydatabase -p 5432"
        echo "User: PGPASSWORD=\"$USER_PASSWORD\" psql --host 127.0.0.1 -U myuser -d mydatabase -p 5432"
        echo
        kubectl port-forward --namespace $NAMESPACE svc/$RELEASE_NAME 5432:5432
        ;;
    4)
        echo "=== CONNECTION INFORMATION ==="
        echo "Service: $RELEASE_NAME.$NAMESPACE.svc.cluster.local:5432"
        echo "Admin User: postgres"
        echo "Admin Password: $POSTGRES_PASSWORD"
        echo "Database User: myuser"
        echo "User Password: $USER_PASSWORD"
        echo "Database Name: mydatabase"
        ;;
    *)
        echo "Invalid choice"
        ;;
esac
