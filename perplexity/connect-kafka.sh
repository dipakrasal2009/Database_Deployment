#!/bin/bash
# Kafka Connection Helper Script
RELEASE_NAME="my-kafka"
NAMESPACE="messaging"
KAFKA_USERNAME="kafka-user"

echo "Choose Kafka operation:"
echo "1. Create a topic"
echo "2. Producer (send messages)"
echo "3. Consumer (receive messages)"
echo "4. List topics"
echo "5. Port forward for external access"
echo "6. Show connection info"

read -p "Enter choice (1-6): " choice

case $choice in
    1)
        read -p "Enter topic name: " topic_name
        kubectl run ${RELEASE_NAME}-admin --restart='Never' -it --rm \
            --namespace $NAMESPACE \
            --image docker.io/bitnami/kafka:latest \
            -- kafka-topics.sh \
            --bootstrap-server $RELEASE_NAME.$NAMESPACE.svc.cluster.local:9092 \
            --create --topic $topic_name --partitions 3 --replication-factor 1
        ;;
    2)
        read -p "Enter topic name: " topic_name
        echo "Starting producer. Type messages and press Enter to send. Use Ctrl+C to exit."
        kubectl run ${RELEASE_NAME}-producer --restart='Never' -it --rm \
            --namespace $NAMESPACE \
            --image docker.io/bitnami/kafka:latest \
            -- kafka-console-producer.sh \
            --bootstrap-server $RELEASE_NAME.$NAMESPACE.svc.cluster.local:9092 \
            --topic $topic_name
        ;;
    3)
        read -p "Enter topic name: " topic_name
        echo "Starting consumer. Use Ctrl+C to exit."
        kubectl run ${RELEASE_NAME}-consumer --restart='Never' -it --rm \
            --namespace $NAMESPACE \
            --image docker.io/bitnami/kafka:latest \
            -- kafka-console-consumer.sh \
            --bootstrap-server $RELEASE_NAME.$NAMESPACE.svc.cluster.local:9092 \
            --topic $topic_name \
            --from-beginning
        ;;
    4)
        kubectl run ${RELEASE_NAME}-admin --restart='Never' -it --rm \
            --namespace $NAMESPACE \
            --image docker.io/bitnami/kafka:latest \
            -- kafka-topics.sh \
            --bootstrap-server $RELEASE_NAME.$NAMESPACE.svc.cluster.local:9092 \
            --list
        ;;
    5)
        echo "Setting up port forward..."
        echo "Kafka will be available at localhost:9092"
        echo "Use Ctrl+C to stop port forwarding"
        kubectl port-forward --namespace $NAMESPACE svc/$RELEASE_NAME 9092:9092
        ;;
    6)
        echo "=== CONNECTION INFORMATION ==="
        echo "Service: $RELEASE_NAME.$NAMESPACE.svc.cluster.local:9092"
        echo "Username: kafka-user"
        echo "Replica Count: 1"
        echo "KRaft Mode: true"
        ;;
    *)
        echo "Invalid choice"
        ;;
esac
