#!/bin/bash
# 02-install-debezium.sh
# Install Debezium PostgreSQL connector plugin into Kafka Connect

set -e

DEBEZIUM_VERSION="2.7.0.Final"
BASE_USER="ssm-user"                        # ganti jika user berbeda
KAFKA_DIR="/home/${BASE_USER}/kafka-lab/kafka"
PLUGIN_DIR="${KAFKA_DIR}/plugins/debezium-postgres"

# FIX 1: nama artifact Maven yang benar adalah "debezium-connector-postgres"
#         bukan "debezium-connector-postgresql"
DEBEZIUM_FILE="debezium-connector-postgres-${DEBEZIUM_VERSION}-plugin.tar.gz"
DEBEZIUM_URL="https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/${DEBEZIUM_VERSION}/${DEBEZIUM_FILE}"

echo "Downloading Debezium ${DEBEZIUM_VERSION}..."
mkdir -p "${PLUGIN_DIR}"
cd "${PLUGIN_DIR}"

if [ ! -f "${DEBEZIUM_FILE}" ]; then
  wget "${DEBEZIUM_URL}"
fi

# FIX 2: extract plugin sebelum restart Connect
# Plugin harus di-extract dulu agar terbaca oleh Connect
echo "Extracting plugin..."
tar -xzf "${DEBEZIUM_FILE}"

# FIX 3: pastikan bootstrap.servers sudah localhost (bukan remote IP)
# Connect perlu reach broker saat startup untuk membuat internal topics:
# connect-configs, connect-offsets, connect-status.
# Kalau remote Kafka tidak reachable, Connect akan crash sebelum REST API port 8083 buka.


sed -i "s|^bootstrap.servers=.*|bootstrap.servers=10.20.10.219:9092|" \
  /home/ssm-user/kafka-lab/kafka/config/connect-distributed.properties
grep "^bootstrap.servers" /home/ssm-user/kafka-lab/kafka/config/connect-distributed.properties


echo "Restarting Kafka Connect to load plugin..."
pkill -f connect-distributed || true
sleep 5

cd "${KAFKA_DIR}"
bin/connect-distributed.sh -daemon config/connect-distributed.properties

# FIX 4: tunggu lebih lama, 15 detik tidak cukup untuk Connect initialize
echo "Waiting for Kafka Connect to initialize..."
sleep 30

echo "Checking plugin is loaded..."
PLUGIN_CHECK=$(curl -s http://localhost:8083/connector-plugins | python3 -m json.tool | grep -i "PostgresConnector" || true)

if [ -n "$PLUGIN_CHECK" ]; then
  echo "Debezium PostgreSQL connector loaded: ${PLUGIN_CHECK}"
else
  echo "Plugin not found. Check logs:"
  tail -50 "${KAFKA_DIR}/logs/connectDistributed.out"
  echo ""
  echo "Verify plugin.path in connect-distributed.properties:"
  grep plugin.path "${KAFKA_DIR}/config/connect-distributed.properties"
  exit 1
fi

echo "Done. Next: bash scripts/03-validate-rds.sh"