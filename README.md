# Data Streaming Pipeline with Kafka & Debezium

AWS infrastructure for real-time data streaming using Change Data Capture (CDC) with Debezium, Kafka, and Apache Iceberg tables.

## Architecture

```
RDS PostgreSQL → Debezium → Kafka → S3 Bronze → Lambda → S3 Silver
```

### Components

- **RDS PostgreSQL** - Source database with logical replication for CDC
- **EC2 Debezium** - Captures database changes using Debezium Connect
- **EC2 Kafka** - Single-node Kafka broker for message streaming
- **S3 Bronze** - Raw data lake (Apache Iceberg format)
- **Lambda Functions** - Process and transform data
- **S3 Silver** - Curated data lake with processed data
- **Bastion Host** - Secure SSH access to private resources

All resources deployed in private subnets with NAT Gateway for outbound access.

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured
- SSH key pair for EC2 instances

## Project Structure

```
.
├── modules/
│   ├── network/              # VPC, subnets, NAT gateway
│   ├── rds-postgres/         # RDS PostgreSQL with CDC
│   ├── ec2-cluster/          # Kafka, Debezium instances
│   ├── ec2-bastion/          # Bastion host
│   ├── s3tables-buckets/     # S3 Iceberg tables
│   └── lambda-private/       # Lambda functions
└── environments/
    └── prod/                 # Production config
```

## Quick Start

### 1. Configure Variables

```bash
cd environments/prod
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region   = "ap-southeast-3"
aws_profile  = "your-profile"
project_name = "your-project"
vpc_cidr     = "10.20.0.0/16"

db_name     = "your_db"
db_username = "postgres"
db_password = "YourSecurePassword123!"
```

### 2. Deploy

```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```

### 3. Access Private Instances

**Option 1: SSH Config (Recommended)**

Create SSH config (`~/.ssh/config`):

```
Host bastion
    HostName <bastion-public-ip>
    User ec2-user
    IdentityFile /path/to/key.pem

Host kafka
    HostName <kafka-private-ip>
    User ubuntu
    ProxyJump bastion
    IdentityFile /path/to/key.pem
```

Connect:
```bash
ssh kafka
```

**Option 2: Port Forwarding**

Forward local port to private instance:

```bash
# Windows
ssh -i "path\to\key.pem" `
  -N `
  -L <local-port>:<private-ip>:<remote-port> `
  ec2-user@<bastion-public-ip>

# Linux/Mac
ssh -i "path/to/key.pem" \
  -N \
  -L <local-port>:<private-ip>:<remote-port> \
  ec2-user@<bastion-public-ip>
```

Example: Access Kafka UI on localhost:8080
```bash
ssh -i "pem-bastion/key.pem" -N -L 8080:<kafka-private-ip>:8080 ec2-user@<bastion-ip>
```

## Modules

**network** - VPC, subnets, NAT gateway, route tables

**rds-postgres** - PostgreSQL with logical replication, encryption, backups

**ec2-cluster** - Kafka, Debezium, spare instances with security groups

**lambda-private** - VPC-enabled Lambda functions with IAM roles

**s3tables-buckets** - Bronze/Silver buckets with versioning and encryption

**ec2-bastion** - Bastion host for secure SSH access

## Security

- All resources in private subnets
- Bastion host for SSH access
- Least privilege security groups
- Encrypted RDS and S3
- No public database access

## Outputs

View deployed resources:
```bash
terraform output
```

## Cleanup

```bash
cd environments/prod
terraform destroy
```

## Notes

- RDS logical replication enabled for CDC
- Single-node Kafka (not HA-ready)
- Adjust instance types per workload
