#!/bin/bash
set -e

NAMESPACE="postgres"
RELEASE_NAME="my-postgres"
CHART_VERSION="16.3.0"

echo "[INFO] Checking prerequisites..."
if ! command -v helm &> /dev/null; then
    echo "[ERROR] Helm is not installed. Please install Helm first."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "[ERROR] kubectl is not installed. Please install kubectl first."
    exit 1
fi

echo "[INFO] Adding Bitnami repo (quay.io compatible)..."
helm repo remove bitnami >/dev/null 2>&1 || true
helm repo add bitnami https://raw.githubusercontent.com/bitnami/charts/archive-full-index/bitnami
helm repo update

echo "[INFO] Creating namespace if not exists..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "[INFO] Creating values-postgres.yaml with production configs..."
cat > values-postgres.yaml <<EOF
global:
  storageClass: "standard"

image:
  registry: quay.io
  repository: bitnami/postgresql
  tag: $CHART_VERSION
  pullPolicy: IfNotPresent

primary:
  persistence:
    enabled: true
    size: 10Gi

auth:
  enablePostgresUser: true
  postgresPassword: "StrongPassword123"
  database: "appdb"

service:
  type: NodePort
  nodePorts:
    postgresql: 30007
  port: 5432
EOF

echo "[INFO] Deploying PostgreSQL using Helm..."
helm upgrade --install $RELEASE_NAME bitnami/postgresql \
  --namespace $NAMESPACE \
  -f values-postgres.yaml \
  --set image.registry=quay.io \
  --set image.repository=bitnami/postgresql \
  --set image.tag=$CHART_VERSION \
  --set global.security.allowInsecureImages=true

echo "[INFO] Waiting for pods to be ready..."
kubectl rollout status statefulset/$RELEASE_NAME-postgresql -n $NAMESPACE

echo "[INFO] PostgreSQL deployed successfully!"
echo "-------------------------------------------"
echo "Namespace     : $NAMESPACE"
echo "Release Name  : $RELEASE_NAME"
echo "Database Name : appdb"
echo "Username      : postgres"
echo "Password      : StrongPassword123"
echo "Access        : NodePort -> <NodeIP>:30007"
echo "-------------------------------------------"

