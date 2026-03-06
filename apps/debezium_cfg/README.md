# CDC Pipeline: Kafka + Debezium + RDS PostgreSQL

End-to-end setup for Change Data Capture (CDC) using Apache Kafka (KRaft mode), Kafka Connect, Debezium, and Amazon RDS PostgreSQL on AWS EC2.

## Repository Structure

```
cdc-docs/
├── README.md
├── docs/
│   ├── 00-concepts.md           concepts: CDC, Kafka, Debezium, KRaft
│   ├── 01-prerequisites.md      checklist before starting
│   └── 02-troubleshooting.md    common errors and fixes
└── scripts/
    ├── 01-install-kafka.sh      install and start Kafka (KRaft)
    ├── 02-install-debezium.sh   install Debezium plugin
    ├── 03-validate-rds.sh       validate RDS PostgreSQL is ready
    ├── 04-deploy-connector.sh   deploy Debezium connector
    ├── 05-health-check.sh       check all components are running
    └── 06-test-cdc.sh           test CDC with real changes
```

## Quick Start

Run these scripts in order for a fresh setup:

```bash
bash scripts/01-install-kafka.sh
bash scripts/02-install-debezium.sh
bash scripts/03-validate-rds.sh
bash scripts/04-deploy-connector.sh
bash scripts/05-health-check.sh
bash scripts/06-test-cdc.sh
```

After an EC2 restart, run:

```bash
bash scripts/05-health-check.sh
```

## Architecture

```
Amazon RDS PostgreSQL
  WAL (wal_level = logical)
  replication slot: debezium_slot
        |
        | logical replication
        v
EC2 (10.20.11.230)
  Kafka Connect (port 8083)
    Debezium PostgreSQL Source Connector
        |
  Kafka KRaft (port 9092)
    topics: dsa.public.transaction, dsa.public.customer, ...
        |
        v
Remote Kafka Cluster (10.20.10.210:9092)
        |
        v
S3 / Iceberg / Consumer
```

## Environment Reference

| Resource | Value |
|---|---|
| EC2 Private IP | `10.20.11.230` |
| RDS Endpoint | `da-data-streaming-2026-postgres.c70mkuqsy7rt.ap-southeast-3.rds.amazonaws.com` |
| Database | `dsa` |
| Kafka (local) | `localhost:9092` |
| Kafka (remote) | `10.20.10.210:9092` |
| Kafka Connect API | `http://localhost:8083` |
| Kafka Version | `4.2.0` |
| PostgreSQL Version | `17.2` |
| Connector Name | `debezium-postgres-connector` |
| Replication Slot | `debezium_slot` |
| Topic Prefix | `dsa` |
| Kafka Install Dir | `/home/ssm-user/kafka-lab/kafka` |