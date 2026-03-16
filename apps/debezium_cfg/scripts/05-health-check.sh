#!/bin/bash
# 05-health-check.sh
# Check all CDC pipeline components are running.
# Run this after every EC2 restart or SSM session reconnect.

BASE_USER="ssm-user"                        
KAFKA_DIR="/home/${BASE_USER}/kafka-lab/kafka"
CONNECT_URL="http://localhost:8083"
CONNECTOR_NAME="debezium-postgres-connector"
KAFKA_LOCAL="localhost:9092"

RDS_HOST="da-data-streaming-2026-postgres.c70mkuqsy7rt.ap-southeast-3.rds.amazonaws.com"
RDS_USER="postgres"
RDS_DB="dsa"

PASS=0
FAIL=0

check() {
  local label="$1"
  local ok="$2"
  local hint="$3"
  if [ "$ok" = "true" ]; then
    echo "  PASS  $label"
    PASS=$((PASS+1))
  else
    echo "  FAIL  $label"
    [ -n "$hint" ] && echo "        $hint"
    FAIL=$((FAIL+1))
  fi
}

echo "Health check: $(date)"
echo ""

# ─────────────────────────────────────────────
# Kafka Broker
# ─────────────────────────────────────────────
echo "Kafka Broker"

if ps aux | grep -q "[k]afka.Kafka"; then
  check "process running" "true"
else
  check "process running" "false" \
    "Start: cd ${KAFKA_DIR} && bin/kafka-server-start.sh -daemon config/server.properties"
  # FIX: config path berubah di Kafka 4.x, tidak ada lagi config/kraft/server.properties
fi

TOPICS=$(${KAFKA_DIR}/bin/kafka-topics.sh --bootstrap-server ${KAFKA_LOCAL} --list 2>/dev/null || echo "")
if [ -n "$TOPICS" ] || ${KAFKA_DIR}/bin/kafka-topics.sh --bootstrap-server ${KAFKA_LOCAL} --list > /dev/null 2>&1; then
  check "responding on port 9092" "true"
else
  check "responding on port 9092" "false" \
    "Broker not responding. Restart: cd ${KAFKA_DIR} && bin/kafka-server-start.sh -daemon config/server.properties"
fi

echo ""

# ─────────────────────────────────────────────
# Kafka Connect internal topics
# ─────────────────────────────────────────────
# FIX: internal topics harus dibuat manual sebelum Connect distart.
# Tanpa topics ini, Connect timeout dan crash sebelum port 8083 buka.
echo "Kafka Connect Internal Topics"

for topic in connect-configs connect-offsets connect-status; do
  if ${KAFKA_DIR}/bin/kafka-topics.sh --bootstrap-server ${KAFKA_LOCAL} --list 2>/dev/null | grep -q "^${topic}$"; then
    check "topic: ${topic}" "true"
  else
    check "topic: ${topic}" "false" \
      "Create: ${KAFKA_DIR}/bin/kafka-topics.sh --bootstrap-server ${KAFKA_LOCAL} --create --topic ${topic} --partitions 1 --replication-factor 1 --config cleanup.policy=compact"
  fi
done

echo ""

# ─────────────────────────────────────────────
# Kafka Connect
# ─────────────────────────────────────────────
# FIX: Connect mati setiap kali SSM session disconnect.
# Harus di-restart manual setelah reconnect.
echo "Kafka Connect"

CONNECT_RESP=$(curl -s --max-time 5 "${CONNECT_URL}/" 2>/dev/null || echo "")
if echo "$CONNECT_RESP" | grep -q "version"; then
  CONNECT_VERSION=$(echo "$CONNECT_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])" 2>/dev/null)
  check "running (v${CONNECT_VERSION})" "true"
else
  check "running" "false" \
    "Start: cd ${KAFKA_DIR} && bin/connect-distributed.sh -daemon config/connect-distributed.properties && sleep 30"
fi

# FIX: pastikan bootstrap.servers tidak ke-reset ke IP remote
BOOTSTRAP=$(grep "^bootstrap.servers=" "${KAFKA_DIR}/config/connect-distributed.properties" 2>/dev/null | cut -d= -f2)
if [ "$BOOTSTRAP" = "localhost:9092" ]; then
  check "bootstrap.servers=localhost:9092" "true"
else
  check "bootstrap.servers=localhost:9092" "false" \
    "Fix: sed -i 's|^bootstrap.servers=.*|bootstrap.servers=localhost:9092|' ${KAFKA_DIR}/config/connect-distributed.properties"
fi

echo ""

# ─────────────────────────────────────────────
# Debezium Connector
# ─────────────────────────────────────────────
echo "Debezium Connector"

CONNECTOR_LIST=$(curl -s --max-time 5 "${CONNECT_URL}/connectors" 2>/dev/null || echo "[]")
if echo "$CONNECTOR_LIST" | grep -q "${CONNECTOR_NAME}"; then
  check "connector registered" "true"

  STATUS_RESP=$(curl -s --max-time 5 "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status" 2>/dev/null)
  CONNECTOR_STATE=$(echo "$STATUS_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['connector']['state'])" 2>/dev/null || echo "UNKNOWN")
  TASK_STATE=$(echo "$STATUS_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['tasks'][0]['state'])" 2>/dev/null || echo "UNKNOWN")

  [ "$CONNECTOR_STATE" = "RUNNING" ] && check "connector state: RUNNING" "true" || \
    check "connector state: ${CONNECTOR_STATE}" "false" \
      "Restart: curl -X POST ${CONNECT_URL}/connectors/${CONNECTOR_NAME}/restart"

  [ "$TASK_STATE" = "RUNNING" ] && check "task state: RUNNING" "true" || \
    check "task state: ${TASK_STATE}" "false" \
      "Check logs: tail -50 ${KAFKA_DIR}/logs/connectDistributed.out"
else
  check "connector registered" "false" "Deploy: bash scripts/04-deploy-connector.sh"
fi

echo ""

# ─────────────────────────────────────────────
# RDS Replication Slot
# ─────────────────────────────────────────────
echo "RDS Replication Slot"

if [ -z "$PGPASSWORD" ]; then
  echo "  SKIP  PGPASSWORD not set. Export it to enable this check."
  echo "        export PGPASSWORD='your_password'"
else
  SLOT_INFO=$(psql -h ${RDS_HOST} -U ${RDS_USER} -d ${RDS_DB} -t \
    -c "SELECT active FROM pg_replication_slots WHERE slot_name = 'debezium_slot';" \
    2>/dev/null | xargs || echo "")

  if [ -n "$SLOT_INFO" ]; then
    check "slot exists" "true"
    [ "$SLOT_INFO" = "t" ] && check "slot active" "true" || \
      check "slot active" "false" "Connector may not be running"
  else
    check "slot exists" "false" "Deploy connector: bash scripts/04-deploy-connector.sh"
  fi
fi

echo ""

# ─────────────────────────────────────────────
# Summary & Auto-fix hint
# ─────────────────────────────────────────────
echo "Result: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Quick restart sequence if all components are down (e.g. after SSM reconnect):"
  echo "  cd ${KAFKA_DIR}"
  echo "  bin/kafka-server-start.sh -daemon config/server.properties && sleep 15"
  echo "  bin/connect-distributed.sh -daemon config/connect-distributed.properties && sleep 30"
  echo "  curl -s http://localhost:8083/ | python3 -m json.tool"
fi