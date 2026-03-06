# Concepts

## CDC (Change Data Capture)

CDC is a technique for capturing every data change (INSERT, UPDATE, DELETE) from a database in real-time. Instead of running periodic full scans, CDC reads the database transaction log, making it efficient and low-latency.

```
User runs INSERT / UPDATE / DELETE
        |
PostgreSQL writes to WAL
        |
Debezium reads WAL via replication slot
        |
Event published to Kafka topic as JSON
        |
Consumer reads and writes to target (S3, another DB, etc.)
```

## Components

**Apache Kafka** is a distributed event streaming platform. Data is stored in topics and can be consumed by many independent consumers. In a CDC pipeline, Kafka acts as the buffer and distributor of change events from the database to downstream systems.

**Kafka Connect** is a framework within the Kafka ecosystem for connecting Kafka to external systems without writing custom code. It is managed via a REST API on port `8083`. A source connector reads from an external system into Kafka. A sink connector writes from Kafka to an external system.

**KRaft** is Kafka's operating mode without Zookeeper. Since Kafka 3.x, KRaft is stable and Zookeeper is deprecated. Metadata is managed internally using the Raft consensus algorithm, meaning only one process is needed per broker.

**Debezium** is an open-source CDC platform that runs as a Kafka Connect source connector. It reads the PostgreSQL WAL via logical replication and converts each row change into a JSON event published to a Kafka topic.

```
Kafka          ->  the platform (event highway)
Kafka Connect  ->  integration framework
Debezium       ->  connector plugin, specializes in database CDC
KRaft          ->  Kafka operating mode, no Zookeeper needed
```

## WAL and Replication Slot

The WAL (Write-Ahead Log) is PostgreSQL's internal transaction log. It is not a separate replica — it lives inside the same PostgreSQL instance alongside the actual data files.

```
RDS PostgreSQL (single instance)
  data files   ->  actual table rows
  WAL files    ->  log of every change (built-in)
```

A replication slot is a bookmark inside the WAL, created specifically for Debezium. It serves two purposes: tracking how far Debezium has read, and preventing PostgreSQL from deleting WAL segments that Debezium has not yet consumed.

```
WAL
  LSN 9/A4000000  INSERT row 1001
  LSN 9/A4000100  UPDATE row 1001
  LSN 9/A4000300  DELETE row 1001  <- debezium_slot points here
  LSN 9/A4000400  INSERT row 1002  <- not yet consumed
```

If Debezium stops for a long time, WAL will accumulate on disk because the slot prevents deletion. Monitor `pg_replication_slots` regularly.

## Kafka Event Format

Each PostgreSQL change produces a JSON event in the corresponding Kafka topic:

```json
{
  "op": "c",
  "before": null,
  "after": {
    "transaction_id": 1097,
    "customer_id": 65,
    "amount": 150.00,
    "payment_method": "debit_card",
    "status": "completed",
    "category": "Food"
  },
  "source": {
    "db": "dsa",
    "table": "transaction",
    "lsn": 40936408664,
    "ts_ms": 1772608948805
  }
}
```

| op | Operation | before | after |
|---|---|---|---|
| `c` | INSERT | null | new row |
| `u` | UPDATE | old row | new row |
| `d` | DELETE | old row | null |
| `r` | Snapshot read | null | existing row |

## Topic Naming

One topic maps to one table, following this convention:

```
{topic.prefix}.{schema}.{table}

dsa.public.transaction  ->  table: transaction, schema: public
dsa.public.customer     ->  table: customer, schema: public
```