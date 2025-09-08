#!/bin/bash

# Script: deploy_postgres.sh
# Purpose: Deploy PostgreSQL on Kubernetes (single node cluster) with NodePort access
# Author: Dipak Rasal

NAMESPACE="database"
POSTGRES_USER="admin"
POSTGRES_PASSWORD="admin123"
POSTGRES_DB="mydb"
NODEPORT=30007   # NodePort range: 30000-32767

echo "🚀 Creating namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "🔐 Creating PostgreSQL Secret..."
kubectl -n $NAMESPACE create secret generic postgres-secret \
  --from-literal=POSTGRES_USER=$POSTGRES_USER \
  --from-literal=POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  --from-literal=POSTGRES_DB=$POSTGRES_DB \
  --dry-run=client -o yaml | kubectl apply -f -

echo "📦 Deploying PostgreSQL Deployment & NodePort Service..."
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
  type: NodePort
  ports:
    - port: 5432
      targetPort: 5432
      nodePort: $NODEPORT
  selector:
    app: postgres
EOF

echo "✅ PostgreSQL deployed successfully with NodePort!"
echo "👉 Connect using: <NodeIP>:$NODEPORT"
echo "👉 Username: $POSTGRES_USER | Password: $POSTGRES_PASSWORD | Database: $POSTGRES_DB"

