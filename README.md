# AWS 3-Tier Architecture

A production-ready Terraform implementation of a classic 3-tier architecture on AWS, suitable for a cloud engineering portfolio.

## Architecture

```
Internet → Public ALB (HTTPS) → Private EC2 Auto Scaling Group → Private RDS (MySQL)
```

### Network Segmentation

| Tier | Subnets | Route Table | Internet Access |
|------|---------|-------------|-----------------|
| Public (ALB/NAT) | 2 AZs | IGW → 0.0.0.0/0 | Yes (inbound/outbound) |
| Private (Application) | 2 AZs | NAT GW → 0.0.0.0/0 | Outbound only |
| Isolated (Database) | 2 AZs | Local VPC only | None |

### Traffic Flow

1. **Internet → ALB**: HTTPS (443) only; HTTP (80) redirects to HTTPS
2. **ALB → Application**: HTTP (80) via security group reference
3. **Application → Database**: MySQL (3306) via security group reference
4. **Application → Internet**: Outbound via NAT Gateway (patches, updates)

### High Availability

- **Multi-AZ**: All subnets span 2 availability zones
- **ALB**: Spans both public subnets
- **ASG**: Instances distributed across private subnets
- **RDS**: Single-AZ for dev; Multi-AZ for prod
- **NAT Gateway**: Single NAT GW for dev; one per AZ for prod

## Repository Structure

```
3-tier-architecture/
├── environments/
│   ├── dev/
│   │   └── infra/          # Dev environment composition
│   │       ├── main.tf
│   │       ├── providers.tf
│   │       ├── variables.tf
│   │       └── terraform.tfvars
│   │
│   └── prod/
│       └── infra/          # Prod environment composition
│           ├── main.tf
│           ├── providers.tf
│           ├── variables.tf
│           └── terraform.tfvars
│
├── modules/
│   ├── compute/
│   │   ├── alb/            # ALB, target group, listeners, HTTPS
│   │   └── asg/            # Launch template, ASG, IMDSv2, encrypted gp3
│   ├── database/
│   │   └── rds/            # RDS MySQL, encryption, Secrets Manager
│   ├── networking/
│   │   └── vpc/            # VPC, subnets, IGW, NAT GW, route tables
│   └── security/
│       ├── iam/            # IAM role, instance profile, SSM
│       └── security_group/ # Reusable SG with rule objects
│
└── README.md
```

## Module Responsibilities

| Module Group | Modules | Responsibility |
|--------------|---------|----------------|
| **compute** | alb, asg | Application load balancing and compute fleet |
| **database** | rds | Managed database with encryption and secrets |
| **networking** | vpc | Network foundation, three-tier segmentation |
| **security** | iam, security_group | Identity, least-privilege network controls |

## Environment Differences

| Capability | Dev | Prod |
|------------|-----|------|
| NAT Gateway | Single (1) | Per AZ (2) |
| EC2 Instance Type | t3.micro | t3.medium |
| ASG Min/Max/Desired | 1 / 2 / 1 | 2 / 6 / 3 |
| RDS Instance Class | db.t3.micro | db.t3.medium |
| RDS Multi-AZ | No | Yes |
| Deletion Protection | No | Yes |
| Backup Retention | 7 days | 30 days |
| ACM Certificate | Self-signed | Validated (configurable) |

## Security Model

- **No SSH access**: All instance management via SSM Session Manager
- **Security group references**: Tier-to-tier traffic uses SG IDs, not CIDR blocks
- **Database isolation**: DB subnets have no route to NAT GW or IGW
- **Encrypted storage**: RDS storage encryption, EBS root volume encryption (gp3)
- **IMDSv2 enforced**: Instance metadata service v2 required
- **Secrets Manager**: Database password auto-generated and stored
- **IAM least privilege**: EC2 role only has `AmazonSSMManagedInstanceCore`
- **HTTPS enforced**: ALB terminates TLS 1.3, HTTP redirects to HTTPS

## Deployment

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.7.0
- S3 bucket + DynamoDB table for remote state (optional but recommended)

### Dev Environment

```bash
cd environments/dev/infra
terraform init
terraform plan
terraform apply
```

### Prod Environment

```bash
cd environments/prod/infra
terraform init
terraform plan
terraform apply
```

**Note**: Each environment has its own state. Configure the `backend "s3"` block in `providers.tf` with environment-specific keys to enable remote state storage.

### Key Variables (overridable via .tfvars)

| Variable | Dev Default | Prod Default |
|----------|-------------|--------------|
| `region` | us-east-1 | us-east-1 |
| `instance_type` | t3.micro | t3.medium |
| `asg_min_size` / `asg_max_size` / `asg_desired_capacity` | 1 / 2 / 1 | 2 / 6 / 3 |
| `db_instance_class` | db.t3.micro | db.t3.medium |
| `multi_az` | false | true |
| `deletion_protection` | false | true |
| `backup_retention_period` | 7 | 30 |
| `nat_gateway_count` | 1 | 2 |
| `acm_certificate_arn` | (self-signed) | "" (supply validated ARN) |

### Accessing the Application

After deployment:
- **ALB DNS**: Output `alb_dns_name`
- **HTTPS**: `https://<alb_dns_name>` (dev uses self-signed cert; browser will warn)
- **SSM**: `aws ssm start-session --target <instance-id>`

### Database Credentials

The database password is auto-generated and stored in AWS Secrets Manager. Retrieve it:

```bash
aws secretsmanager get-secret-value --secret-id <secret-arn> --query SecretString --output text
```

The secret ARN is available in the RDS module output `master_user_secret_arn`.

## Destruction

```bash
cd environments/dev/infra   # or prod/infra
terraform destroy
```

**Warning**: `deletion_protection = false` on dev RDS. For production, it is enabled by default and must be disabled before destroy.

## Cost Considerations

### Dev (Monthly Estimate, us-east-1)

| Resource | Estimate |
|----------|----------|
| NAT Gateway (1) | ~$45 |
| ALB | ~$22 |
| EC2 (1× t3.micro) | ~$7.50 |
| RDS (db.t3.micro, 20GB gp3) | ~$15 |
| **Total (approx)** | **~$90/month** |

### Prod (Monthly Estimate, us-east-1)

| Resource | Estimate |
|----------|----------|
| NAT Gateway (2) | ~$90 |
| ALB | ~$22 |
| EC2 (3× t3.medium) | ~$90 |
| RDS (db.t3.medium, 20GB gp3, Multi-AZ) | ~$120 |
| **Total (approx)** | **~$322/month** |

**Dev optimizations**:
- Single NAT Gateway
- Single-AZ RDS
- Minimal instance sizes
- Shorter backup retention

**Prod hardening**:
- NAT Gateway per AZ
- RDS Multi-AZ
- Larger instances
- Longer backup retention
- Deletion protection

## Customization

### Use Validated ACM Certificate (Prod)

Set `acm_certificate_arn` in `terraform.tfvars`:

```hcl
acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxx"
```

Requires DNS-validated certificate in ACM (Route 53 or manual DNS).

### Adjust NAT Gateway Strategy

Controlled via `nat_gateway_count`:
- `1` = single NAT GW (dev default)
- `2` = one per AZ (prod default for 2 AZs)

### Enable RDS Multi-AZ

Set `multi_az = true` (prod default).

## Validation

```bash
# Dev
cd environments/dev/infra
terraform fmt -recursive
terraform init
terraform validate
terraform plan

# Prod
cd environments/prod/infra
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

## Module Versions

- AWS Provider: ~> 6.0
- TLS Provider: ~> 4.0
- terraform-aws-modules/rds/aws: ~> 6.0

## License

MIT