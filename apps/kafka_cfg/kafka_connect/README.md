### Build Iceberg Plugins

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