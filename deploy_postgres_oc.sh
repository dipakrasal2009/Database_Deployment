#!/bin/bash
# Deploy PostgreSQL on OpenShift (NodePort)

NAMESPACE="database"
POSTGRES_USER="admin"
POSTGRES_PASSWORD="admin123"
POSTGRES_DB="mydb"
NODEPORT=30007

echo "🚀 Creating project: $NAMESPACE"
oc new-project $NAMESPACE || echo "Project already exists"

echo "🔐 Creating secret..."
oc -n $NAMESPACE create secret generic postgres-secret \
  --from-literal=POSTGRES_USER=$POSTGRES_USER \
  --from-literal=POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  --from-literal=POSTGRES_DB=$POSTGRES_DB \
  --dry-run=client -o yaml | oc apply -f -

echo "📦 Deploying PostgreSQL..."
cat <<EOF | oc apply -n $NAMESPACE -f -
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
      securityContext:
        runAsUser: 999
        fsGroup: 999
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
        emptyDir: {}
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

echo "✅ PostgreSQL deployed on OpenShift!"
echo "👉 Connect using: <NodeIP>:$NODEPORT"

