# Vektor-Guard Data Plane

[![Terraform](https://img.shields.io/badge/IaC-Terraform_1.9+-7b42bc?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-232f3e?logo=amazonaws&logoColor=white)](https://aws.amazon.com/)
[![Databricks](https://img.shields.io/badge/Lakehouse-Databricks-ff3621?logo=databricks&logoColor=white)](https://www.databricks.com/)
[![Delta Lake](https://img.shields.io/badge/Storage-Delta_Lake-00ADD4?logo=databricks&logoColor=white)](https://delta.io/)
[![Python](https://img.shields.io/badge/Python-3.13-3776ab?logo=python&logoColor=white)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/API-FastAPI-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Docker](https://img.shields.io/badge/Container-Docker-2496ed?logo=docker&logoColor=white)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Phase_1_in_progress-orange)](#build-status)

A closed-loop telemetry and training-data pipeline for the [Vektor-Guard](https://huggingface.co/theinferenceloop/vektor-guard-v1) prompt-injection and jailbreak classifier. Every production inference becomes a candidate training example — versioned, governed, and traceable from raw event back to the model artifact it trains.

> **Why this exists.** AI security models decay. Attackers evolve, the training distribution goes stale, and a classifier that doesn't see production traffic can't learn from it. Most AI security products ship a model and never close the loop. This project is the data plane that closes it.

---

## Table of contents

- [Architecture](#architecture)
- [Project status](#project-status)
- [Tech stack](#tech-stack)
- [Repository structure](#repository-structure)
- [Quick start](#quick-start)
- [Documentation](#documentation)
- [Roadmap](#roadmap)
- [License](#license)
- [Author](#author)

---

## Architecture

Two-phase build. Phase 1 ships a working end-to-end pipeline on a single EC2 instance. Phase 2 refactors the judge worker to event-driven serverless, demonstrating the monolith → microservices transition as its own portfolio artifact.

<p align="center">
  <img src="img/variant1_ec2_only.png" alt="Phase 1 architecture — Variant 1 EC2-only" width="800">
</p>

The data plane serves two consumption paths from a single medallion lakehouse:

<p align="center">
  <img src="img/gold_layer_consumers.png" alt="Gold layer consumers" width="800">
</p>

| Loop | Latency | Consumer | Purpose |
|---|---|---|---|
| **Slow** | Weekly+ | `gold.training_candidates_v{n}` | Offline fine-tuning, versioned datasets |
| **Fast** | Daily | `gold.threat_intel_daily` | Threat intel feed, dashboards, newsletter |
| **Fast** | Minutes | `gold.session_context` | Runtime risk policy decisions |
| **Fast** | Daily | `gold.model_performance` | Drift detection, registry promotion gates |
| **Fast** | Hourly | `silver.inference_events_clean` (filter: `disagreement_flag=true`) | Analyst review queue → high-quality labels |

Full architecture, design rationale, and decision log: **[docs/architecture.md](docs/architecture.md)**.

---

## Project status

**Phase 1 — in progress.** Building the EC2-only pipeline, end to end.

| Phase | Scope | Status |
|---|---|---|
| **Phase 1** | EC2 monolith runtime + medallion + MLflow lifecycle | 🚧 In progress |
| **Phase 2** | Refactor judge worker → Lambda + SQS event-driven | ⏳ Planned |

### Build status — Phase 1

- [ ] Terraform foundation (providers, variables, tagging)
- [ ] AWS infrastructure (IAM, VPC, S3, Secrets Manager, CloudWatch, EC2, EventBridge)
- [ ] Databricks setup (UC volume, schema, grants, service principal)
- [ ] Runtime services (FastAPI emit, sync agent, judge worker)
- [ ] CI/CD (GitHub Actions → ECR → SSM Run Command)
- [ ] Medallion (bronze ingestion, silver enrichment, gold curation)
- [ ] MLflow lifecycle and Model Registry promotion gates
- [ ] End-to-end smoke test

---

## Tech stack

### AWS infrastructure
EC2 `t4g.large` (Graviton2) · IAM (least-privilege instance profile) · S3 (event archive, lifecycle to Glacier) · Secrets Manager · SSM Parameter Store · CloudWatch Logs/Metrics/Alarms · ECR · EventBridge Scheduler

### Infrastructure as code
Terraform 1.9+ · AWS provider `~> 5.70` · Databricks provider · `tflint` · `checkov`

### CI/CD
GitHub Actions · Self-hosted runner (Proxmox) · AWS SSM Run Command · `docker buildx` (ARM64 native, M4 → Graviton)

### Runtime — Vektor-Guard service
Python 3.13 · FastAPI · Uvicorn (Gunicorn workers) · Pydantic v2 · transformers + PyTorch CPU (ModernBERT-large) · structlog · prometheus-client · databricks-sdk-py · boto3 · Docker · Docker Compose · Systemd

### Databricks data plane (Free Edition)
Unity Catalog (tags, row filters, column masks, lineage, audit) · Delta Lake · Auto Loader · Structured Streaming · Lakeflow Declarative Pipelines · MLflow · Model Registry · Feature Store (offline) · Databricks SQL

### External services
HuggingFace Hub (model artifacts, SHA-pinned) · Anthropic API (Claude judge) · OpenAI API (GPT judge) · Weights & Biases (training tracking)

### Observability
CloudWatch · MLflow UI · Unity Catalog audit logs · Databricks SQL dashboards

---

## Repository structure

```text
vektor-guard-data-plane/
├── README.md                  # this file
├── .gitignore
├── LICENSE
├── docs/
│   ├── architecture.md        # full design, rationale, decision log
│   └── img/                   # diagrams referenced from docs
├── terraform/                 # AWS + Databricks infrastructure
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── locals.tf
│   ├── iam.tf
│   ├── network.tf
│   ├── s3.tf
│   ├── secrets.tf
│   ├── logs.tf
│   ├── ec2.tf
│   ├── scheduler.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── docker/
│   ├── Dockerfile.runtime
│   └── docker-compose.yml
└── src/
    └── vektor_guard_runtime/  # Python service code
        ├── fastapi_app.py     # inference endpoint + event emitter
        ├── sync_agent.py      # rolling file sink → UC volume sync
        └── judge_worker.py    # dual-LLM verdict generation
```

---

## Quick start

> ⚠️ This project is in active development. The instructions below describe the target state. See [Project status](#project-status) for what currently works.

### Prerequisites

- **Local tooling:** Terraform 1.9+, AWS CLI v2, Docker (or OrbStack), Python 3.13, Databricks CLI, GitHub CLI
- **Cloud accounts:** AWS account with admin (for initial bootstrap), Databricks Free Edition workspace, HuggingFace account, Anthropic + OpenAI API keys

### Bootstrap

```bash
# 1. Clone and enter
git clone https://github.com/<owner>/vektor-guard-data-plane.git
cd vektor-guard-data-plane

# 2. Configure variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit terraform/terraform.tfvars with your account values

# 3. Plan and apply infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# 4. Populate secrets
aws secretsmanager put-secret-value --secret-id vektor-guard-dp-dev/databricks-pat --secret-string "<your-PAT>"
aws secretsmanager put-secret-value --secret-id vektor-guard-dp-dev/anthropic-key --secret-string "<your-key>"
aws secretsmanager put-secret-value --secret-id vektor-guard-dp-dev/openai-key --secret-string "<your-key>"

# 5. Build and push runtime image
cd ../docker
docker buildx build --platform linux/arm64 -t vektor-guard-runtime:latest -f Dockerfile.runtime ..
# (CI/CD handles ECR push and SSM deploy)
```

### Cost note

EventBridge schedules start the EC2 instance at 07:00 and stop it at 00:00 local. At `t4g.large` on-demand pricing this keeps the runtime under ~$20/month. Databricks Free Edition is $0. Total monthly cost target during development: **under $30**.

---

## Documentation

| Document | Purpose |
|---|---|
| **[docs/architecture.md](docs/architecture.md)** | Full architecture, design rationale, decision log |
| **[docs/img/](docs/img/)** | Architecture diagrams (PNG) |

---

## Roadmap

### Phase 1 — EC2 monolith ⬅ *current*
End-to-end pipeline. One EC2 instance hosts FastAPI, judge worker, sync agent. Medallion lakehouse. MLflow lifecycle. Two gold tables: `training_candidates_v{n}`, `model_performance`.

### Phase 2 — Event-driven judge split
Refactor judge worker to AWS Lambda triggered via SQS. EC2 slims to FastAPI + sync agent only. Adds gold tables: `threat_intel_daily`, `session_context`. Demonstrates monolith → microservices transition.

### Future

- Multi-tenant simulation (synthetic tenants for governance demonstration)
- TrustTrace integration (commercial deployment, separate stack)
- Real-time feature serving for sub-100ms risk scoring

---

## License

MIT — see [LICENSE](LICENSE).

---

## Author

**Matt Sikes** · Principal Architect · [The Inference Loop](https://theinferenceloop.substack.com)

Building open-source AI security tools and writing about AI infrastructure at [theinferenceloop.substack.com](https://theinferenceloop.substack.com). Related work:

- **[Vektor-Guard](https://huggingface.co/theinferenceloop/vektor-guard-v1)** — the model this data plane serves
- **[The Inference Loop](https://theinferenceloop.substack.com)** — newsletter and open-source lab
