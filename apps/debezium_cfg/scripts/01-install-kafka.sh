#!/bin/bash
# 01-install-kafka.sh
# Install Apache Kafka (KRaft mode) and Kafka Connect on Amazon Linux 2023

set -e

KAFKA_VERSION="4.2.0"
SCALA_VERSION="2.13"
BASE_USER="ssm-user"                        # ganti jika user berbeda
BASE_DIR="/home/${BASE_USER}/kafka-lab"
KAFKA_DIR="${BASE_DIR}/kafka"
KAFKA_PACKAGE="kafka_${SCALA_VERSION}-${KAFKA_VERSION}"

echo "Installing Java..."
sudo dnf install -y java-17-amazon-corretto wget
java -version

echo "Downloading Kafka ${KAFKA_VERSION}..."
mkdir -p "${BASE_DIR}"
cd "${BASE_DIR}"

if [ ! -f "${KAFKA_PACKAGE}.tgz" ]; then
  wget "https://downloads.apache.org/kafka/${KAFKA_VERSION}/${KAFKA_PACKAGE}.tgz"
fi

tar -xzf "${KAFKA_PACKAGE}.tgz"
mv "${KAFKA_PACKAGE}" kafka 2>/dev/null || true

echo "Setting up KRaft (no Zookeeper)..."
cd "${KAFKA_DIR}"

KAFKA_CLUSTER_ID=$(bin/kafka-storage.sh random-uuid)
echo "Cluster ID: ${KAFKA_CLUSTER_ID}"

# FIX 1: config path berubah di Kafka 4.x (tidak ada lagi config/kraft/)
# FIX 2: tambah --standalone untuk single node tanpa controller.quorum.voters
bin/kafka-storage.sh format \
  -t "${KAFKA_CLUSTER_ID}" \
  -c config/server.properties \
  --standalone

echo "Configuring Kafka Connect..."
mkdir -p "${KAFKA_DIR}/plugins"
cp config/connect-distributed.properties config/connect-distributed.properties.bak

# FIX 3: bootstrap.servers harus localhost:9092 bukan remote IP
# Connect perlu reach broker saat startup untuk membuat internal topics
# (connect-configs, connect-offsets, connect-status).
# Kalau diset ke remote IP yang tidak reachable, Connect crash sebelum port 8083 buka.
sed -i "s|^bootstrap.servers=.*|bootstrap.servers=localhost:9092|" \
  config/connect-distributed.properties

if ! grep -q "^plugin.path=" config/connect-distributed.properties; then
  echo "plugin.path=${KAFKA_DIR}/plugins" >> config/connect-distributed.properties
fi

echo "Starting Kafka..."
bin/kafka-server-start.sh -daemon config/server.properties

echo "Waiting for Kafka to be ready..."
sleep 10

bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
echo "Kafka is running."

# FIX 4: buat internal topics Connect secara manual
# Tanpa ini, Connect akan timeout saat mencoba membuat topics sendiri
# dan crash sebelum REST API port 8083 siap menerima request.
echo "Creating Kafka Connect internal topics..."
bin/kafka-topics.sh --bootstrap-server localhost:9092 --create \
  --topic connect-configs --partitions 1 --replication-factor 1 \
  --config cleanup.policy=compact

bin/kafka-topics.sh --bootstrap-server localhost:9092 --create \
  --topic connect-offsets --partitions 25 --replication-factor 1 \
  --config cleanup.policy=compact

bin/kafka-topics.sh --bootstrap-server localhost:9092 --create \
  --topic connect-status --partitions 5 --replication-factor 1 \
  --config cleanup.policy=compact

echo "Starting Kafka Connect..."
bin/connect-distributed.sh -daemon config/connect-distributed.properties

# FIX 5: sleep ditambah jadi 30 detik (15 detik terlalu singkat)
echo "Waiting for Kafka Connect to initialize..."
sleep 30

curl -s http://localhost:8083/ | python3 -m json.tool

echo "Done. Next: bash scripts/02-install-debezium.sh"