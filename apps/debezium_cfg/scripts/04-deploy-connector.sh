#!/bin/bash
# 04-deploy-connector.sh
# Deploy Debezium PostgreSQL connector to Kafka Connect

set -e

CONNECT_URL="http://localhost:8083"
CONNECTOR_NAME="debezium-postgres-connector"
CONFIG_FILE="/tmp/debezium-config.json"

RDS_HOST="da-data-streaming-2026-postgres.c70mkuqsy7rt.ap-southeast-3.rds.amazonaws.com"
RDS_PORT="5432"
RDS_USER="postgres"
RDS_DB="dsa"
TOPIC_PREFIX="dsa"
SLOT_NAME="debezium_slot"

echo "Checking Kafka Connect..."
if ! curl -s "${CONNECT_URL}/" | grep -q "version"; then
  echo "Kafka Connect is not running. Run scripts/01-install-kafka.sh first."
  exit 1
fi

echo "Existing connectors:"
curl -s "${CONNECT_URL}/connectors"
echo ""

EXISTING=$(curl -s "${CONNECT_URL}/connectors")
if echo "$EXISTING" | grep -q "${CONNECTOR_NAME}"; then
  echo "Connector '${CONNECTOR_NAME}' already exists."
  read -p "Delete and redeploy? (y/N): " CONFIRM
  if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
    curl -s -X DELETE "${CONNECT_URL}/connectors/${CONNECTOR_NAME}"
    echo "Connector deleted. Waiting..."
    sleep 5
  else
    echo "Skipping. Current status:"
    curl -s "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status" | python3 -m json.tool
    exit 0
  fi
fi

if [ -z "$PGPASSWORD" ]; then
  read -s -p "RDS password: " RDS_PASSWORD
  echo ""
else
  RDS_PASSWORD="$PGPASSWORD"
fi

echo "Writing connector config to ${CONFIG_FILE}..."
cat > "${CONFIG_FILE}" << EOF
{
  "name": "${CONNECTOR_NAME}",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "${RDS_HOST}",
    "database.port": "${RDS_PORT}",
    "database.user": "${RDS_USER}",
    "database.password": "${RDS_PASSWORD}",
    "database.dbname": "${RDS_DB}",
    "topic.prefix": "${TOPIC_PREFIX}",
    "plugin.name": "pgoutput",
    "slot.name": "${SLOT_NAME}",
    "publication.autocreate.mode": "all_tables",
    "schema.include.list": "public",
    "snapshot.mode": "initial",
    "heartbeat.interval.ms": "5000"
  }
}
EOF

# FIX 1: hapus "database.server.name" — config ini deprecated di Debezium 2.x,
#         digantikan oleh "topic.prefix"

echo "Deploying connector..."
curl -s -X POST "${CONNECT_URL}/connectors" \
  -H "Content-Type: application/json" \
  -d @"${CONFIG_FILE}" | python3 -m json.tool

echo "Waiting for connector to start..."
sleep 10

echo "Connector status:"
curl -s "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status" | python3 -m json.tool

echo "Done. Next: bash scripts/06-test-cdc.sh"