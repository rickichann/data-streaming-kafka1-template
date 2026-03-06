# Prerequisites

## EC2

| Item | Requirement |
|---|---|
| OS | Amazon Linux 2023 |
| VPC | Must be the same VPC as the RDS instance |
| Java | JDK 11 or higher |
| Ports | `9092` (Kafka), `8083` (Kafka Connect) |

## RDS PostgreSQL

| Item | Requirement | How to set |
|---|---|---|
| PostgreSQL version | 10 or higher | - |
| `wal_level` | `logical` | Set `rds.logical_replication = 1` in Parameter Group, then reboot |
| `pgoutput` plugin | Built-in since PG 10, no installation needed | - |
| User privilege | Master user must be able to create replication slots | Default on RDS |

### Enabling logical replication on RDS

1. Go to AWS Console > RDS > Parameter Groups
2. Open the parameter group attached to your instance
3. Find `rds.logical_replication` and set it to `1`
4. Save changes
5. Reboot the RDS instance
6. Verify: `SHOW wal_level;` should return `logical`

## Networking

| Resource | Required rule |
|---|---|
| RDS Security Group | Inbound port `5432` from the EC2 security group |
| EC2 Security Group | Outbound to RDS (usually allowed by default) |

EC2 and RDS must be in the same VPC. You can verify by running `hostname -I` on EC2 — the IP should be in the same range as the RDS private IP.

To add the inbound rule on the RDS security group: go to EC2 > Security Groups, select the RDS security group, edit inbound rules, and add a PostgreSQL rule (port 5432) with the EC2 security group as the source. Using the security group as source is preferred over hardcoding an IP.

## What to ask DevOps

Two things require AWS Console access:

Enable logical replication:
> "Please set `rds.logical_replication = 1` in the RDS Parameter Group for instance `da-data-streaming-2026-postgres`, then reboot the instance."

Open the security group:
> "Please add an inbound rule to the RDS security group: port 5432, source = the security group of the EC2 instance running Kafka."