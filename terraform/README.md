# Terraform — EC2 + S3 + IAM

A minimal but production-grade AWS infrastructure module.

## What it provisions

- **EC2 instance** — Amazon Linux 2023, IMDSv2-only, encrypted EBS, SSM-managed (no SSH)
- **S3 bucket** — AES-256 encryption, versioning, public-access fully blocked, TLS-only via bucket policy, lifecycle rules
- **IAM role + instance profile** — least-privilege S3 access scoped to this bucket only, plus CloudWatch + SSM
- **Security group** — HTTP/HTTPS in, no SSH

## Files

| File | Contents |
|---|---|
| `main.tf` | Terraform + provider config, common tags |
| `variables.tf` | Input variables with validation |
| `ec2.tf` | EC2 instance + AMI lookup + security group |
| `s3.tf` | S3 bucket with hardened defaults |
| `iam.tf` | IAM role, policies, instance profile |
| `outputs.tf` | Instance ID, bucket name, SSM session command |
| `terraform.tfvars.example` | Sample configuration |

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

## Connect to the instance (no SSH)

```bash
# Install SSM plugin once: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

aws ssm start-session --target $(terraform output -raw instance_id)
```

## What this shows that toy examples miss

| Pattern | Why it matters |
|---|---|
| **IMDSv2-only** (`http_tokens = "required"`) | Blocks the classic SSRF → AWS credential theft attack chain (Capital One breach, 2019) |
| **Encrypted root volume** | At-rest encryption is a baseline compliance requirement |
| **No SSH** — SSM only | No key rotation, no bastion host, no exposed port 22, full audit trail via CloudTrail |
| **S3 public-access block** | Defends against accidentally-public buckets even if a policy is misconfigured |
| **TLS-only bucket policy** | Denies any non-HTTPS access at the policy level |
| **Inline IAM policy** — scoped to bucket ARN | NOT `s3:*` on `*`. Each statement names the exact bucket and key prefix |
| **Lifecycle rules** | Auto-transitions old versions to cheaper storage; expires after retention period |
| **Variable validation** | `terraform plan` fails fast on invalid input instead of mid-apply |

## Cleanup

```bash
terraform destroy
```

The S3 bucket has versioning enabled — Terraform will refuse to destroy it if it contains objects. To force:

```bash
aws s3 rm s3://$(terraform output -raw bucket_name) --recursive
terraform destroy
```
