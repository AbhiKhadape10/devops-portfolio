# CI/CD Pipelines

Two equivalent pipelines for the same goal:

```
lint → test → SAST → build → image scan → push to ECR → deploy to ECS
```

Both fail fast — cheap checks first, expensive checks later.

## github-actions/deploy.yml

Modern GitHub-native pipeline. Key features:

- **OIDC federation to AWS** — no long-lived `AWS_ACCESS_KEY_ID` secrets stored in GitHub. Each run assumes the IAM role for ~1 hour
- **Trivy** for filesystem scan (source code) AND image scan (built container)
- **Bandit** for Python-specific SAST
- **SARIF upload** to GitHub Code Scanning — findings appear in the Security tab
- **GitHub Environments** for production approval gates
- **`ecs wait services-stable`** for deploy verification

### Setup

1. Create the IAM role for GitHub OIDC (one-time setup):
   ```bash
   aws iam create-role --role-name github-actions-deploy \
       --assume-role-policy-document file://trust-policy.json
   ```
2. Replace `000000000000` in the workflow with your AWS account ID
3. Configure a "production" environment in GitHub repo settings with required reviewers

## jenkins/Jenkinsfile

Declarative Jenkins pipeline for teams on existing Jenkins infra. Key features:

- **Docker-in-Docker agents** — each stage runs in an isolated container, no global tool installs
- **Manual approval gate** via `input` step before production deploy
- **JUnit test results** parsed for the dashboard
- **`buildDiscarder`** keeps the last 20 builds; older logs auto-pruned
- **`disableConcurrentBuilds`** prevents racing deploys

### Setup

1. Install plugins: AWS Steps, Docker Pipeline, Pipeline AnsiColor
2. Add AWS credentials with ID `aws-jenkins` (IAM user with deploy permissions)
3. Replace `000000000000` with your AWS account ID

## What both demonstrate

| Practice | Why it matters |
|---|---|
| Lint + test before build | Cheapest failure modes fail in <1 minute |
| SAST before image build | Don't push code-level vulnerabilities to ECR |
| Image scan AFTER build | Catches base-image CVEs invisible to source scans |
| OIDC over static keys (GHA) | No secrets to rotate; short-lived credentials per run |
| Conditional deploy (`main` only) | PRs don't accidentally deploy to prod |
| `wait services-stable` | Deploy job fails if ECS doesn't reach steady state |
| Workspace cleanup in `post` | No disk-full on Jenkins agents |

## Pipeline timing (typical)

```
lint-test       ~1m
security-scan   ~30s
build-push      ~2m
image-scan      ~30s
deploy          ~3m  (incl. wait-for-stable)
─────────────────────
Total           ~7m   on PR / push to main
```
