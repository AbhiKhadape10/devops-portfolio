# DevOps Portfolio

Infrastructure-as-code, CI/CD, and container orchestration patterns demonstrating production-grade DevOps practices on AWS.

```
devops-portfolio/
├── terraform/      → IaC: EC2 + S3 + IAM with secure defaults
├── cicd/           → CI/CD pipelines (GitHub Actions + Jenkins)
└── containers/     → Containerized FastAPI app + Kubernetes manifests
```

## What this demonstrates

| Section | Skills shown |
|---|---|
| **terraform/** | Modular IaC, IMDSv2 enforcement, IAM least-privilege, S3 hardening, SSM Session Manager (no SSH) |
| **cicd/** | Multi-stage pipeline: lint → test → SAST → image scan → push → deploy. OIDC federation, no static AWS keys |
| **containers/** | Multi-stage Docker, non-root, K8s with HPA, IRSA, probes, pod security context |

## Architecture

```
┌─────────────────┐  push   ┌─────────────────┐  scan   ┌─────────────────┐
│   GitHub Repo   │ ──────► │  GitHub Actions │ ──────► │   Trivy SAST    │
└─────────────────┘         └────────┬────────┘         └─────────────────┘
                                     │ pass
                                     ▼
                            ┌─────────────────┐         ┌─────────────────┐
                            │   Build image   │ ──────► │   ECR + scan    │
                            └────────┬────────┘         └─────────────────┘
                                     │ pass
                                     ▼
                            ┌─────────────────┐
                            │ ECS / EKS deploy│
                            └────────┬────────┘
                                     │
                ┌────────────────────┼────────────────────┐
                ▼                    ▼                    ▼
        ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
        │   App Pods   │ ── │  S3 (IRSA)   │    │  CloudWatch  │
        │   (FastAPI)  │    │  (encrypted) │    │   metrics    │
        └──────────────┘    └──────────────┘    └──────────────┘
                ▲
                │ HPA: 3→20 pods on CPU / memory
                └──────────────────────────────
```

## Quick start

Each subdirectory is independent. Pick what you want to explore:

```bash
# Terraform — provision the AWS resources
cd terraform/
cp terraform.tfvars.example terraform.tfvars  # edit with your values
terraform init && terraform plan

# Container — build & test locally
cd containers/
docker build -t demo-app -f Dockerfile .
docker run -p 8000:8000 demo-app

# Kubernetes — apply manifests (needs kubectl context set)
kubectl apply -f containers/k8s/

# GitHub Actions — runs automatically on push to main
```

## Highlights

### Security defaults that aren't optional in production

- **IMDSv2-only EC2** — blocks the SSRF → metadata credential theft chain
- **No SSH** — SSM Session Manager only. No key rotation. No bastion hosts
- **OIDC for CI** — GitHub Actions assumes an AWS role per run; no long-lived `AWS_ACCESS_KEY_ID`
- **IRSA for pods** — each pod assumes its own IAM role via OIDC; node-level credentials irrelevant
- **Trivy at three points** — repo filesystem, built image, deployed image
- **All buckets**: AES-256 encryption, versioning, public-access fully blocked
- **All containers**: non-root, no privilege escalation, dropped capabilities, read-only root filesystem

### CI/CD that fails fast

Cheap checks first, expensive checks later:

```
lint  →  test  →  SAST  →  build  →  image scan  →  push  →  deploy
~30s    ~1m    ~30s     ~2m       ~30s         ~10s    ~2m
```

A bad commit fails in 30 seconds, not 6 minutes.

### Kubernetes patterns that actually matter at scale

- **Separate liveness vs readiness probes** — liveness = "process is up", readiness = "can serve traffic". Mixing them breaks rolling updates.
- **HPA with asymmetric scale behavior** — scale up fast on spikes, scale down slow to avoid flapping
- **Topology spread constraints** — pods distributed across AZs for resilience
- **PodSecurity** — `runAsNonRoot`, `readOnlyRootFilesystem`, dropped capabilities, seccomp `RuntimeDefault`

## Tech stack

- **Cloud**: AWS (EC2, S3, IAM, ECR, ECS, EKS, CloudWatch, SSM)
- **IaC**: Terraform 1.5+
- **CI/CD**: GitHub Actions, Jenkins
- **Containers**: Docker (multi-stage), Kubernetes 1.28+
- **Application**: Python 3.12, FastAPI
- **Security tooling**: Trivy, Bandit

## License

MIT — fork & adapt freely.
