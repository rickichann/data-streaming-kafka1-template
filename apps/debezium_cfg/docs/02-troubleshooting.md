# Troubleshooting

## Kafka not responding on port 9092

Check if the process is running:

```bash
ps aux | grep kafka
```

If not running, start it:

```bash
cd /home/ssm-user/kafka-lab/kafka
bin/kafka-server-start.sh -daemon config/kraft/server.properties
```

## Kafka Connect not responding on port 8083

Check the process and logs:

```bash
ps aux | grep connect-distributed
tail -100 /home/ssm-user/kafka-lab/kafka/logs/connect.log
```

Restart Kafka Connect:

```bash
cd /home/ssm-user/kafka-lab/kafka
pkill -f connect-distributed
sleep 5
bin/connect-distributed.sh -daemon config/connect-distributed.properties
```

Internal topics (`connect-configs`, `connect-offsets`, `connect-status`) not appearing usually means Kafka Connect has not finished starting. Wait 10-15 seconds and check again.

## RDS connection timed out

The RDS security group is not allowing traffic on port 5432 from this EC2. Verify both are in the same VPC with `hostname -I`, and ask DevOps to add the inbound rule.

## `wal_level` is `replica` instead of `logical`

The parameter `rds.logical_replication` has not been set in the RDS Parameter Group, or the instance has not been rebooted yet after the change.

## `permission denied to alter role`

This is expected on RDS. The master user cannot self-grant the REPLICATION attribute, but it can still create replication slots, which is all Debezium needs.

## Connector state is FAILED

Get the error detail:

```bash
curl -s http://localhost:8083/connectors/debezium-postgres-connector/status | python3 -m json.tool
```

Try restarting the connector without redeploying:

```bash
curl -X POST http://localhost:8083/connectors/debezium-postgres-connector/restart
```

## Connector already exists (409 error)

Check its current status first. If it is running, there is nothing to do. If you need to redeploy:

```bash
curl -X DELETE http://localhost:8083/connectors/debezium-postgres-connector
sleep 5
curl -s -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @/tmp/debezium-config.json | python3 -m json.tool
```

## Debezium plugin not found

Check that the plugin is registered:

```bash
curl -s http://localhost:8083/connector-plugins | python3 -m json.tool | grep -i postgres
```

If empty, verify the plugin directory and the `plugin.path` setting:

```bash
ls /home/ssm-user/kafka-lab/kafka/plugins/
grep plugin.path /home/ssm-user/kafka-lab/kafka/config/connect-distributed.properties
```

Then restart Kafka Connect for it to pick up the plugin.

## WAL accumulating on RDS

This happens when Debezium has been inactive for a long time. The replication slot prevents PostgreSQL from deleting unconsumed WAL segments. Check the lag:

```sql
SELECT slot_name,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS lag
FROM pg_replication_slots;
```

If Debezium is no longer needed, drop the slot:

```sql
SELECT pg_drop_replication_slot('debezium_slot');
```

## After EC2 restart

Always start Kafka before Kafka Connect. The correct order is:

1. Start Kafka, wait 5 seconds
2. Start Kafka Connect, wait 10-15 seconds
3. Check connector status — it usually recovers automatically

Run `bash scripts/05-health-check.sh` to verify everything.