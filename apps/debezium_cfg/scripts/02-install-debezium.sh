#!/bin/bash
# 02-install-debezium.sh
# Install Debezium PostgreSQL connector plugin into Kafka Connect

set -e

DEBEZIUM_VERSION="2.7.0.Final"
KAFKA_DIR="/home/ssm-user/kafka-lab/kafka"
PLUGIN_DIR="${KAFKA_DIR}/plugins/debezium-postgres"
DEBEZIUM_FILE="debezium-connector-postgresql-${DEBEZIUM_VERSION}-plugin.tar.gz"
DEBEZIUM_URL="https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgresql/${DEBEZIUM_VERSION}/${DEBEZIUM_FILE}"

echo "Downloading Debezium ${DEBEZIUM_VERSION}..."
mkdir -p "${PLUGIN_DIR}"
cd "${PLUGIN_DIR}"

if [ ! -f "${DEBEZIUM_FILE}" ]; then
  wget "${DEBEZIUM_URL}"
fi

echo "Extracting plugin..."
tar -xzf "${DEBEZIUM_FILE}"

echo "Restarting Kafka Connect to load plugin..."
pkill -f connect-distributed || true
sleep 5

cd "${KAFKA_DIR}"
bin/connect-distributed.sh -daemon config/connect-distributed.properties
echo "Waiting for Kafka Connect to initialize..."
sleep 15

echo "Checking plugin is loaded..."
PLUGIN_CHECK=$(curl -s http://localhost:8083/connector-plugins | python3 -m json.tool | grep -i "PostgresConnector" || true)

if [ -n "$PLUGIN_CHECK" ]; then
  echo "Debezium PostgreSQL connector loaded: ${PLUGIN_CHECK}"
else
  echo "Plugin not found. Verify plugin.path in connect-distributed.properties:"
  grep plugin.path "${KAFKA_DIR}/config/connect-distributed.properties"
  exit 1
fi

echo "Done. Next: bash scripts/03-validate-rds.sh"