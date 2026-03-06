#!/bin/bash
# 05-health-check.sh
# Check all CDC pipeline components are running.
# Run this after every EC2 restart.

KAFKA_DIR="/home/ssm-user/kafka-lab/kafka"
CONNECT_URL="http://localhost:8083"
CONNECTOR_NAME="debezium-postgres-connector"
KAFKA_LOCAL="localhost:9092"
KAFKA_REMOTE="10.20.10.210:9092"

RDS_HOST="xxxxxx.rds.amazonaws.com"
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

# Kafka
echo "Kafka"
if ps aux | grep -q "[k]afka.Kafka"; then
  check "process running" "true"
else
  check "process running" "false" \
    "Start: cd ${KAFKA_DIR} && bin/kafka-server-start.sh -daemon config/kraft/server.properties"
fi

TOPICS=$(${KAFKA_DIR}/bin/kafka-topics.sh --bootstrap-server ${KAFKA_LOCAL} --list 2>/dev/null || echo "")
if [ -n "$TOPICS" ]; then
  check "responding on port 9092" "true"
else
  check "responding on port 9092" "false"
fi

echo ""

# Kafka Connect
echo "Kafka Connect"
CONNECT_RESP=$(curl -s "${CONNECT_URL}/" 2>/dev/null || echo "")
if echo "$CONNECT_RESP" | grep -q "version"; then
  CONNECT_VERSION=$(echo "$CONNECT_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])" 2>/dev/null)
  check "running (v${CONNECT_VERSION})" "true"
else
  check "running" "false" \
    "Start: cd ${KAFKA_DIR} && bin/connect-distributed.sh -daemon config/connect-distributed.properties"
fi

for topic in connect-configs connect-offsets connect-status; do
  if echo "$TOPICS" | grep -q "$topic"; then
    check "internal topic: ${topic}" "true"
  else
    check "internal topic: ${topic}" "false"
  fi
done

echo ""

# Debezium connector
echo "Debezium Connector"
CONNECTOR_LIST=$(curl -s "${CONNECT_URL}/connectors" 2>/dev/null || echo "[]")
if echo "$CONNECTOR_LIST" | grep -q "${CONNECTOR_NAME}"; then
  check "connector registered" "true"

  STATUS_RESP=$(curl -s "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status" 2>/dev/null)
  CONNECTOR_STATE=$(echo "$STATUS_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['connector']['state'])" 2>/dev/null || echo "UNKNOWN")
  TASK_STATE=$(echo "$STATUS_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['tasks'][0]['state'])" 2>/dev/null || echo "UNKNOWN")

  [ "$CONNECTOR_STATE" = "RUNNING" ] && check "connector state: RUNNING" "true" || \
    check "connector state: ${CONNECTOR_STATE}" "false" \
      "Restart: curl -X POST ${CONNECT_URL}/connectors/${CONNECTOR_NAME}/restart"

  [ "$TASK_STATE" = "RUNNING" ] && check "task state: RUNNING" "true" || \
    check "task state: ${TASK_STATE}" "false"
else
  check "connector registered" "false" "Deploy: bash scripts/04-deploy-connector.sh"
fi

echo ""

# RDS replication slot
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
    check "slot exists" "false"
  fi
fi

echo ""

# Remote Kafka
echo "Remote Kafka (${KAFKA_REMOTE})"
NC_OUT=$(nc -zv $(echo $KAFKA_REMOTE | tr ':' ' ') 2>&1 || true)
if echo "$NC_OUT" | grep -q "Connected"; then
  check "reachable" "true"
else
  check "reachable" "false" "Check security group or VPC peering"
fi

echo ""
echo "Result: ${PASS} passed, ${FAIL} failed"