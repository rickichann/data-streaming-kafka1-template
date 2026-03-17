# Build Iceberg Plugins

Before starting Kafka Connect, you need to build the Iceberg plugins:
```bash
docker run -it --name iceberg-build -v "$PWD":/workspace eclipse-temurin:17-jdk bash
apt-get update && apt-get install -y git unzip wget

wget https://services.gradle.org/distributions/gradle-8.5-bin.zip
unzip gradle-8.5-bin.zip -d /opt && export PATH=/opt/gradle-8.5/bin:$PATH

# Clone and build iceberg
cd /workspace && git clone https://github.com/apache/iceberg.git && cd iceberg
./gradlew -x test -x integrationTest clean build
```

After the build completes, extract zip file and copy all JARs in `lib` directory to `kafka_connect/plugins`:

```bash
unzip iceberg/kafka-connect/kafka-connect-runtime/build/distributions/iceberg-kafka-connect-runtime-SNAPSHOT.zip
cp -v iceberg-kafka-connect-runtime-SNAPSHOT/lib/*.jar kafka_connect/plugins/
```

### Start Kafka Connect

```bash
cd kafka_connect
docker-compose up -d
```

# Deploy Connectors

Use the provided CLI tool `connect_cli.sh` to manage connectors.

### Example Connector Deploy Command

```bash
./kafka_connect/connect_cli.sh deploy kafka_connect/configs/dbz_customers_iceberg_sink.json
```

---

## Connector CLI

The `connect_cli.sh` script provides the following commands:

| Command | Description |
|---------|-------------|
| `deploy <connector.json>` | Deploy or update a connector |
| `status <connector.json \| name>` | Show connector status |
| `delete <connector.json \| name>` | Delete a connector |
| `config <connector.json \| name>` | Show connector configuration |
| `restart <connector.json \| name>` | Restart connector and tasks |
| `pause <connector.json \| name>` | Pause connector |
| `resume <connector.json \| name>` | Resume connector |
| `list` | List all connectors |

### Environment Variables

- `CONNECT_URL` - Kafka Connect API URL (default: `http://localhost:8083`)

### Prerequisites

- `jq` must be installed:
  - Ubuntu: `sudo apt install jq`
  - MacOS: `brew install jq`