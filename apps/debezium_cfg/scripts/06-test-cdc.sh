#!/bin/bash
# 06-test-cdc.sh
# Test CDC pipeline by running INSERT, UPDATE, DELETE on PostgreSQL
# and verifying events appear in the Kafka topic.

BASE_USER="ssm-user"                        # ganti jika user berbeda
KAFKA_DIR="/home/${BASE_USER}/kafka-lab/kafka"
KAFKA_BOOTSTRAP="localhost:9092"            # FIX: pakai local Kafka, bukan remote IP
TOPIC="dsa.public.transaction"

RDS_HOST="da-data-streaming-2026-postgres.c70mkuqsy7rt.ap-southeast-3.rds.amazonaws.com"
RDS_USER="postgres"
RDS_DB="dsa"

if [ -z "$PGPASSWORD" ]; then
  read -s -p "RDS password: " PGPASSWORD
  echo ""
  export PGPASSWORD
fi

PSQL="psql -h ${RDS_HOST} -U ${RDS_USER} -d ${RDS_DB} -p 5432"

echo "Available Kafka topics (dsa.*):"
${KAFKA_DIR}/bin/kafka-topics.sh --bootstrap-server ${KAFKA_BOOTSTRAP} --list 2>/dev/null | grep "^dsa\." || \
  echo "  (no dsa.* topics found yet — connector may still be doing initial snapshot)"

echo ""
echo "WAL position before changes:"
$PSQL -c "SELECT pg_current_wal_lsn();"
$PSQL -c "SELECT slot_name, confirmed_flush_lsn FROM pg_replication_slots WHERE slot_name = 'debezium_slot';"

echo ""
echo "Open a second terminal and run the consumer:"
echo ""
echo "  ${KAFKA_DIR}/bin/kafka-console-consumer.sh \\"
echo "    --bootstrap-server ${KAFKA_BOOTSTRAP} \\"           # FIX: konsisten pakai local
echo "    --topic ${TOPIC} \\"
echo "    --from-beginning"
echo ""
read -p "Press Enter when the consumer is ready..."

echo ""
echo "Running INSERT..."
$PSQL -c "
INSERT INTO transaction (customer_id, amount, payment_method, status, category)
VALUES (165, 999.99, 'credit_card', 'pending', 'CDC_TEST');
"
echo "Expected in Kafka: op=c, after.category=CDC_TEST"
sleep 2

echo ""
echo "Running UPDATE..."
$PSQL -c "
UPDATE transaction
SET status = 'completed'
WHERE category = 'CDC_TEST' AND customer_id = 165;
"
echo "Expected in Kafka: op=u, before.status=pending, after.status=completed"
sleep 2

echo ""
echo "Running DELETE..."
$PSQL -c "
DELETE FROM transaction
WHERE category = 'CDC_TEST' AND customer_id = 165;
"
echo "Expected in Kafka: op=d, after=null"
sleep 2

echo ""
echo "WAL position after changes:"
$PSQL -c "SELECT pg_current_wal_lsn();"
$PSQL -c "SELECT slot_name, confirmed_flush_lsn FROM pg_replication_slots WHERE slot_name = 'debezium_slot';"
echo "confirmed_flush_lsn should have advanced, meaning Debezium consumed the WAL."

echo ""
echo "op reference:"
echo "  c  INSERT"
echo "  u  UPDATE"
echo "  d  DELETE"
echo "  r  snapshot read (initial)"