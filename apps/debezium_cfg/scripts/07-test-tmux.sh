/home/ssm-user/kafka-lab/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server 10.20.10.219:9092 \
  --topic dsa.public.transactions \
  --from-beginning

PSQL="psql -h da-data-streaming-2026-postgres.c70mkuqsy7rt.ap-southeast-3.rds.amazonaws.com -U postgres -d dsa -p 5432"

$PSQL -c "INSERT INTO transactions (transaction_id, customer_id, transaction_date, product_category, amount, status) VALUES ('CDC-TEST-002', 'C001', CURRENT_DATE, 'CDC_TEST', 1001, 'pending');"

$PSQL -c "UPDATE transactions SET status = 'completed' WHERE transaction_id = 'CDC-TEST-001';"

$PSQL -c "DELETE FROM transactions WHERE transaction_id = 'CDC-TEST-001';"