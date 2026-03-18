# S3 Tables Setup

Setup scripts and configuration files for integrating S3 Tables with AWS Lake Formation and Glue Catalog.

## Files

### JSON Configuration Files

**Role-Trust-Policy.json**  
Trust policy allowing Lake Formation service to assume the IAM role. Includes conditions to restrict access to a specific AWS account.

**LF-GluePolicy.json**  
IAM policy granting Lake Formation permissions to manage S3 Tables resources including:
- List table buckets
- Create/delete table buckets and namespaces
- Manage tables (create, delete, rename, update)
- Read/write table data

**catalog.json**  
Glue Catalog configuration for federated S3 Tables catalog with connection settings and permissions.

**input.json**  
Lake Formation resource registration input specifying the S3 Tables bucket ARN, federation settings, and IAM role.

### Bash Script

**create_s3tables_role.sh**  
Executes AWS CLI commands to:
1. Create IAM role with trust policy
2. Attach inline policy to the role
3. Register resource with Lake Formation
4. Create Glue federated catalog

## Usage

1. Update all JSON files with your AWS account ID (replace `111122223333`)
2. Update the S3 Tables bucket ARN and region as needed
3. Execute the setup script:

```bash
bash create_s3tables_role.sh
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Permissions to create IAM roles and policies
- Permissions to register Lake Formation resources
- Permissions to create Glue catalogs
