#!/bin/bash

# Script: deploy_postgres.sh
# Purpose: Deploy PostgreSQL on Kubernetes (single node cluster)
# Author: Dipak Rasal

NAMESPACE="database"
POSTGRES_USER="admin"
POSTGRES_PASSWORD="admin123"
POSTGRES_DB="mydb"

echo "🚀 Creating namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "🔐 Creating PostgreSQL Secret..."
kubectl -n $NAMESPACE create secret generic postgres-secret \
  --from-literal=POSTGRES_USER=$POSTGRES_USER \
  --from-literal=POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  --from-literal=POSTGRES_DB=$POSTGRES_DB \
  --dry-run=client -o yaml | kubectl apply -f -

echo "📦 Deploying PostgreSQL Deployment & Service..."
cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
        envFrom:
        - secretRef:
            name: postgres-secret
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
spec:
  type: ClusterIP
  ports:
    - port: 5432
      targetPort: 5432
  selector:
    app: postgres
EOF

echo "✅ PostgreSQL deployed successfully!"
echo "👉 To connect inside cluster: postgres-service.$NAMESPACE.svc.cluster.local:5432"
echo "👉 Username: $POSTGRES_USER | Database: $POSTGRES_DB"

