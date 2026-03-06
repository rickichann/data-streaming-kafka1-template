#!/bin/bash
# 03-validate-rds.sh
# Validate RDS PostgreSQL is configured for CDC (logical replication)

set -e

RDS_HOST="xxxxxx.rds.amazonaws.com"
RDS_PORT="5432"
RDS_USER="postgres"
RDS_DB="dsa"

if ! command -v psql &> /dev/null; then
  echo "Installing PostgreSQL client..."
  sudo dnf install -y postgresql15
fi

if [ -z "$PGPASSWORD" ]; then
  read -s -p "RDS password: " PGPASSWORD
  echo ""
  export PGPASSWORD
fi

PSQL="psql -h ${RDS_HOST} -U ${RDS_USER} -d ${RDS_DB} -p ${RDS_PORT}"

echo "Testing connectivity..."
if ! $PSQL -c "SELECT 1;" > /dev/null 2>&1; then
  echo "Cannot connect to RDS. Check the security group and VPC."
  echo "EC2 IP: $(hostname -I | awk '{print $1}')"
  exit 1
fi
echo "Connected."

echo "Checking wal_level..."
WAL_LEVEL=$($PSQL -t -c "SHOW wal_level;" | xargs)
echo "wal_level = ${WAL_LEVEL}"

if [ "$WAL_LEVEL" != "logical" ]; then
  echo "wal_level must be 'logical'. Ask DevOps to set rds.logical_replication = 1 and reboot RDS."
  exit 1
fi

echo "Checking replication slots..."
$PSQL -c "SELECT slot_name, plugin, active, inactive_since FROM pg_replication_slots;"

echo "Testing replication slot creation..."
$PSQL -c "SELECT pg_create_logical_replication_slot('validate_slot', 'pgoutput');"
$PSQL -c "SELECT pg_drop_replication_slot('validate_slot');"
echo "Replication slot test passed."

echo "Tables available for CDC:"
$PSQL -c "\dt"

echo "Done. RDS is ready. Next: bash scripts/04-deploy-connector.sh"