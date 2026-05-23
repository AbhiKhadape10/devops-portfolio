# Containers — Dockerized FastAPI + Kubernetes

A minimal FastAPI service containerized with production best practices, deployed to Kubernetes (EKS) with health probes, autoscaling, and pod security.

## Layout

```
containers/
├── Dockerfile           Multi-stage build, non-root user
├── .dockerignore        Keeps build context small
├── app/
│   ├── app.py           FastAPI service with separate liveness/readiness probes
│   ├── requirements.txt
│   └── tests/
│       └── test_app.py
└── k8s/                 Manifests applied in order
    ├── 00-namespace.yaml
    ├── 01-serviceaccount.yaml   ← IRSA: pod-level IAM
    ├── 02-configmap.yaml
    ├── 03-deployment.yaml       ← Pod spec with security context
    ├── 04-service.yaml
    └── 05-hpa.yaml              ← Autoscaling 3 → 20 pods
```

## Dockerfile — what's in each stage

**Stage 1 (builder)**: installs `build-essential` + Python dependencies into `/root/.local`.
**Stage 2 (runtime)**: slim Python image, creates non-root `app` user, copies installed deps from the builder.

Result: smaller final image (no build tools), runs as user 1000, has a Python-based healthcheck (no `curl`/`wget` needed in the image).

## Local testing

```bash
docker build -t demo-app -f Dockerfile .
docker run -p 8000:8000 demo-app

curl http://localhost:8000/         # → service info
curl http://localhost:8000/health/  # → liveness
```

## Deploy to Kubernetes

```bash
# Apply in order — files are numerically prefixed for clarity
kubectl apply -f k8s/

# Verify
kubectl get pods -n demo
kubectl get hpa -n demo
kubectl logs -n demo -l app=demo-app -f
```

## What this demonstrates beyond toy examples

### Separate liveness vs readiness probes

This is the most-misunderstood K8s pattern. They sound similar; they do completely different things:

| Probe | When it fails | Effect |
|---|---|---|
| **Liveness** | Process unresponsive | Pod **restarted** |
| **Readiness** | Dependency (DB/S3/cache) unreachable | Pod **removed from Service** (no restart) |

The app exposes **two endpoints** for this:

- `/health/` returns OK with no external calls — perfect for liveness
- `/health/ready` calls `s3.head_bucket()` — perfect for readiness

If S3 is down, liveness still passes (the process is fine), and the pod gets removed from rotation instead of getting restart-looped while S3 is down.

### IRSA — IAM Roles for Service Accounts

In a non-EKS world, pods get AWS credentials from the **node's** instance profile. That means every pod on the node has the same permissions — a security disaster at scale.

IRSA fixes this. The ServiceAccount has an annotation:

```yaml
eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/demo-app-s3-access
```

Pods using that ServiceAccount get scoped credentials via OIDC. Only this app's pods can touch its S3 bucket; the node's other workloads can't.

### Pod security context

```yaml
runAsNonRoot: true
readOnlyRootFilesystem: true
allowPrivilegeEscalation: false
capabilities: { drop: ["ALL"] }
seccompProfile: { type: RuntimeDefault }
```

Container escape attacks rely on root inside the container + writable rootfs. We disable both. The `tmp` emptyDir volume handles cases where the app needs to write somewhere.

### HPA with asymmetric scale behavior

```yaml
scaleUp:   stabilizationWindowSeconds: 30   policies: [Percent 100, periodSeconds 30]
scaleDown: stabilizationWindowSeconds: 300  policies: [Percent  25, periodSeconds 60]
```

Scale up fast (double the replicas in 30 seconds on a spike) but scale down slow (max 25% reduction per minute, with a 5-min cooldown). Prevents flapping when traffic is oscillating.

### Topology spread constraints

`maxSkew: 1` on `kubernetes.io/hostname` — pods distributed across nodes. One node fails → at most one pod lost.

## Replace before deploying

- `000000000000` in `01-serviceaccount.yaml` and `03-deployment.yaml` — your AWS account ID
- `demo-app-dev-data-abc123` in `02-configmap.yaml` — your actual S3 bucket name
- The ECR image tag in `03-deployment.yaml` — your image
