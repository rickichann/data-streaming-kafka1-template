# Kafka Setup

Kafka deployment using Docker Compose with KRaft mode (no Zookeeper) and Kafka UI for monitoring.

## Prerequisites

- Docker and Docker Compose installed
- `jq` installed (for connector CLI script)
  ```bash
  # Ubuntu/Debian
  sudo apt install jq
  
  # MacOS
  brew install jq
  ```
- AWS credentials configured in `.aws/config` (for S3 Tables integration)
- Network access to advertised listener IP (`10.20.10.219:9092`)

## Services

**Kafka Broker**
- Image: `apache/kafka:4.2.0`
- Port: `9092` (client connections)
- Mode: KRaft (combined broker + controller)
- Advertised listener: `10.20.10.219:9092`

**Kafka UI**
- Image: `provectuslabs/kafka-ui:latest`
- Port: `8080`
- Access: http://localhost:8080

## Deployment

Start Kafka and Kafka UI:

```bash
docker-compose up -d
```

Verify services are running:

```bash
docker-compose ps
```

View logs:

```bash
docker-compose logs -f
```

Stop services:

```bash
docker-compose down
```

## Connector Management

Use `connect-cli.sh` to manage Kafka Connect connectors:

**Deploy a connector:**
```bash
./connect-cli.sh deploy configs/postgre_connector.json
```

**Check connector status:**
```bash
./connect-cli.sh status postgres-connector
```

**List all connectors:**
```bash
./connect-cli.sh list
```

**Delete a connector:**
```bash
./connect-cli.sh delete postgres-connector
```

**Restart a connector:**
```bash
./connect-cli.sh restart postgres-connector
```

**Pause/Resume:**
```bash
./connect-cli.sh pause postgres-connector
./connect-cli.sh resume postgres-connector
```

## Configuration Files

**configs/postgre_connector.json**  
Debezium PostgreSQL source connector for CDC (Change Data Capture)

**configs/iceberg_sink.json**  
Iceberg sink connector for writing to AWS S3 Tables

**configs/dbz_customers_iceberg_sink.json**  
Iceberg sink for customer data

**configs/dbz_transactions_iceberg_sink.json**  
Iceberg sink for transaction data

## AWS Configuration

AWS credentials are mounted from `.aws/config` for S3 Tables access. Update with your credentials:

```ini
[default]
region = ap-southeast-3
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

## Network Configuration

Update `KAFKA_ADVERTISED_LISTENERS` in `docker-compose.yml` to match your host IP if different from `10.20.10.219`.
