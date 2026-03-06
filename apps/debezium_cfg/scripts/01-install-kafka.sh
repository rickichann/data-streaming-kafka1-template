#!/bin/bash
# 01-install-kafka.sh
# Install Apache Kafka (KRaft mode) and Kafka Connect on Amazon Linux 2023

set -e

KAFKA_VERSION="4.2.0"
SCALA_VERSION="2.13"
KAFKA_DIR="/home/ssm-user/kafka-lab/kafka"
KAFKA_PACKAGE="kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
REMOTE_KAFKA="10.20.10.210:9092"

echo "Installing Java..."
sudo dnf install -y java-17-amazon-corretto
java -version

echo "Downloading Kafka ${KAFKA_VERSION}..."
mkdir -p /home/ssm-user/kafka-lab
cd /home/ssm-user/kafka-lab

if [ ! -f "${KAFKA_PACKAGE}.tgz" ]; then
  wget "https://downloads.apache.org/kafka/${KAFKA_VERSION}/${KAFKA_PACKAGE}.tgz"
fi

tar -xzf "${KAFKA_PACKAGE}.tgz"
mv "${KAFKA_PACKAGE}" kafka 2>/dev/null || true

echo "Setting up KRaft (no Zookeeper)..."
cd "${KAFKA_DIR}"

KAFKA_CLUSTER_ID=$(bin/kafka-storage.sh random-uuid)
echo "Cluster ID: ${KAFKA_CLUSTER_ID}"

bin/kafka-storage.sh format \
  -t "${KAFKA_CLUSTER_ID}" \
  -c config/kraft/server.properties

echo "Configuring Kafka Connect..."
mkdir -p "${KAFKA_DIR}/plugins"
cp config/connect-distributed.properties config/connect-distributed.properties.bak

sed -i "s|^bootstrap.servers=.*|bootstrap.servers=${REMOTE_KAFKA}|" \
  config/connect-distributed.properties

if ! grep -q "^plugin.path=" config/connect-distributed.properties; then
  echo "plugin.path=${KAFKA_DIR}/plugins" >> config/connect-distributed.properties
fi

echo "Starting Kafka..."
bin/kafka-server-start.sh -daemon config/kraft/server.properties
sleep 5

bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
echo "Kafka is running."

echo "Starting Kafka Connect..."
bin/connect-distributed.sh -daemon config/connect-distributed.properties
echo "Waiting for Kafka Connect to initialize..."
sleep 15

curl -s http://localhost:8083/ | python3 -m json.tool

echo "Done. Next: bash scripts/02-install-debezium.sh"