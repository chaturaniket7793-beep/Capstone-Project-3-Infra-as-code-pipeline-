# Capstone Project 3 — Terraform + GitHub Actions + AWS ECS

**Zero-Touch CI/CD Deployment Platform**

**Terraform · GitHub Actions · AWS ECS Fargate · Docker · Amazon ECR · Application Load Balancer · CloudWatch · Automated Rollback**

---

## 1. Project Overview and Architecture

This project replaces a manual SSH-based production deployment process with an automated CI/CD platform using **Terraform, GitHub Actions and AWS ECS Fargate**.

Terraform provisions the AWS infrastructure as code. GitHub Actions validates the code, builds the container image, publishes it to Amazon ECR, deploys the application to ECS staging, waits for production approval, deploys to production and validates the deployment.

The platform also supports rollback when a production deployment fails its health validation.

### Architecture workflow

1. Developer creates a feature branch.
2. Developer opens a Pull Request.
3. GitHub Actions starts CI validation.
4. Terraform format, validation and TFLint checks run.
5. Application tests run.
6. Docker image is built.
7. Image is pushed to Amazon ECR.
8. Application is deployed to ECS staging.
9. Staging health is validated.
10. Production deployment requires approval.
11. Application is deployed to ECS production.
12. Production health is validated.
13. Failed deployment can trigger rollback to the previous ECS task definition.

### High-level architecture

```text
                         ┌────────────────────┐
                         │     Developer      │
                         │   Git / Pull Req   │
                         └─────────┬──────────┘
                                   │
                                   ▼
                         ┌────────────────────┐
                         │   GitHub Actions   │
                         │                    │
                         │ Terraform Checks   │
                         │ TFLint             │
                         │ Tests              │
                         │ Docker Build       │
                         └───────┬───────┬────┘
                                 │       │
                         OIDC    │       │ Push Image
                                 │       ▼
                                 │   ┌─────────────┐
                                 │   │ Amazon ECR  │
                                 │   └──────┬──────┘
                                 │          │
                                 ▼          ▼
                         ┌────────────────────────┐
                         │        AWS IAM         │
                         │       OIDC Role        │
                         └────────────────────────┘
                                            │
                                            ▼
                                   ┌────────────────┐
                                   │  ECS Fargate   │
                                   │                │
                                   │ Task 1  Task 2 │
                                   └───────┬────────┘
                                           │
                                           ▼
                                   ┌────────────────┐
                                   │      ALB       │
                                   │      :80       │
                                   └───────┬────────┘
                                           │
                                           ▼
                                      Application

                                  
```

---

## 2. AWS Infrastructure

The infrastructure is deployed inside an AWS VPC using public and private subnets.

```text
AWS VPC
│
├── Public Subnets
│   ├── Application Load Balancer
│   └── NAT Gateway
│
├── Private Subnets
│   └── ECS Fargate Tasks
│
├── Internet Gateway
├── Route Tables
├── Security Groups
├── Amazon ECR
├── IAM Roles

```

### AWS services

| AWS Service | Purpose |
|---|---|
| **VPC** | Network foundation |
| **Public / Private Subnets** | Network isolation |
| **Internet Gateway** | Internet connectivity |
| **NAT Gateway** | Outbound connectivity |
| **Application Load Balancer** | Routes application traffic |
| **ECS Fargate** | Runs containers |
| **Amazon ECR** | Stores Docker images |
| **IAM** | Access control |
| **S3** | Terraform remote state |
| **DynamoDB** | Terraform state locking |

---

## 3. Terraform Infrastructure as Code

Terraform is organized into reusable modules.

```text
terraform/
│
├── providers.tf
├── versions.tf
├── backend.tf
├── variables.tf
├── outputs.tf
├── main.tf
│
├── modules/
│   ├── networking/
│   ├── security/
│   ├── ecr/
│   ├── iam/
│   ├── ecs/
│   ├── alb/
│   
│
└── environments/
    ├── dev/
    ├── staging/
    └── production/
```

### Terraform responsibilities

- VPC and subnet creation
- Route tables and networking
- Security groups
- ECR repository
- IAM roles
- ECS cluster and service
- ECS task definition
- Application Load Balancer
- Remote Terraform state
- Repeatable infrastructure provisioning

---

## 4. CI/CD Pipeline

GitHub Actions provides the automated deployment path from source code to ECS.

```text
Developer
    │
    ▼
Pull Request
    │
    ▼
Terraform Format
    │
    ▼
Terraform Validate
    │
    ▼
TFLint
    │
    ▼
Application Tests
    │
    ▼
Docker Build
    │
    ▼
Push Image to ECR
    │
    ▼
ECS Staging
    │
    ▼
Health Check
    │
    ▼
Production Approval
    │
    ▼
ECS Production
    │
    ▼
Health Check
    │
    ├──────────────► SUCCESS
    │
    └──────────────► FAILURE
                           │
                           ▼
                    Automatic Rollback
```

### CI quality gates

The deployment does not proceed until the required checks pass.

| Stage | Purpose |
|---|---|
| Terraform Format | Check Terraform formatting |
| Terraform Validate | Validate configuration |
| TFLint | Detect Terraform issues |
| Application Tests | Validate application |
| Docker Build | Build container image |
| ECR Push | Publish image |
| ECS Deployment | Deploy application |

---

## 5. GitHub Actions to AWS Authentication

The pipeline uses **GitHub OIDC and an AWS IAM role** instead of storing long-lived AWS access keys in GitHub.

```text
GitHub Actions
      │
      │ OIDC
      ▼
GitHub OIDC Provider
      │
      ▼
AWS IAM Role
      │
      ├── ECR
      └── ECS Deployment
```

### Security controls

- No hard-coded AWS access keys
- Short-lived credentials through OIDC
- IAM role-based access
- ECS tasks run in private subnets
- ECS security group allows application traffic from the ALB
- Production deployment is protected by GitHub Environment approval

---

## 6. Application and Container

The application is a **Node.js service** packaged as a Docker container.

```text
application/
│
├── Dockerfile
├── package.json
├── package-lock.json
│
├── src/
│   ├── server.js
│   └── routes/
│       └── health.js
│
└── tests/
    └── health.test.js
```

### Application configuration

| Item | Value |
|---|---|
| Application | Node.js |
| Container port | `5000` |
| Health endpoint | `/health` |

### Local Docker test

```bash
docker build -t ecs-zero-touch-app:test .
docker run --rm -p 5000:5000 ecs-zero-touch-app:test
```

Test the application:

```text
http://localhost:5000/
http://localhost:5000/health
```

---

## 7. Environment Promotion

The deployment path separates validation from production release.

```text
Development
     │
     ▼
CI Validation
     │
     ▼
Staging
     │
     ▼
Health Validation
     │
     ▼
Production Approval
     │
     ▼
Production
```

Production is protected by a **GitHub Environment approval gate**.

This prevents the workflow from automatically promoting a release to production without authorization.

---

## 8. Deployment and Rollback

The project uses an **ECS rolling deployment** approach.

```text
Current ECS Revision
        │
        ▼
Register New Revision
        │
        ▼
Update ECS Service
        │
        ▼
Health / Stability Check
        │
        ├── PASS ──► Deployment Complete
        │
        └── FAIL
                 │
                 ▼
          Previous Revision
                 │
                 ▼
          Automatic Rollback
```

The deployment process keeps the previous ECS task definition available so an unhealthy release can return to the last known-good revision.

---

## 9. ECS Scaling

The target service supports multiple running tasks.

| Setting | Value |
|---|---:|
| Minimum tasks | **2** |
| Maximum tasks | **6** |

Running multiple tasks provides basic service redundancy while autoscaling allows ECS to increase capacity when required.



## 11. Repository Structure

```text
Capstone-Project-3-Infra-as-code-pipeline/
│
├── .github/
│   └── workflows/
│       ├── terraform-ci.yml
│       └── deploy.yml
│
├── application/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json
│   ├── src/
│   │   ├── server.js
│   │   └── routes/
│   │       └── health.js
│   └── tests/
│       └── health.test.js
│
├── terraform/
│   ├── providers.tf
│   ├── versions.tf
│   ├── backend.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── main.tf
│   ├── modules/
│   │   ├── networking/
│   │   ├── security/
│   │   ├── ecr/
│   │   ├── iam/
│   │   ├── ecs/
│   │   ├── alb/
│   │   └── environments/
│
├── scripts/
│   ├── build-image.sh
│   ├── push-image.sh
│   ├── terraform-plan.sh
│   └── terraform-apply.sh
│
├── docs/
│   ├── architecture.md
│   ├── deployment-flow.md
│   └── troubleshooting.md
│
├── .gitignore
├── README.md
└── LICENSE
```

---

## 12. Setup and Deployment

### Prerequisites

- Git
- AWS CLI
- Terraform
- Docker
- AWS account
- GitHub repository

### Clone repository

```bash
git clone <YOUR-GITHUB-REPOSITORY-URL>
cd Capstone-Project-3-Infra-as-code-pipeline-
```

### Initialize Terraform

```bash
terraform init
```

### Format Terraform

```bash
terraform fmt -recursive
```

### Validate Terraform

```bash
terraform validate
```

### Create a plan

```bash
terraform plan
```

### Apply infrastructure

```bash
terraform apply
```

> Use the environment-specific variable files and commands committed in the repository.

### GitHub Actions deployment

```text
Git Push / Pull Request
        ↓
GitHub Actions
        ↓
CI Validation
        ↓
Docker Build
        ↓
ECR Push
        ↓
ECS Staging
        ↓
Production Approval
        ↓
ECS Production
```

---

## 13. Failure Runbook

### Terraform validation failure

```text
Terraform fmt
     ↓
Terraform validate
     ↓
TFLint
     ↓
Fix configuration
     ↓
Commit changes
```

### Docker build failure

```text
Check Dockerfile
     ↓
Check package.json
     ↓
Run Docker build locally
     ↓
Fix application/container issue
```

### ECS deployment failure

```text
Check ECS service events
     ↓
Check ECS task status
     ↓
Check CloudWatch logs
     ↓
Check ALB target health
     ↓
Validate /health
     ↓
Rollback if required
```

### Production health failure

```text
Health Check Failure
        ↓
Fail Release
        ↓
Restore Previous ECS Revision
        ↓
Validate Previous Version
```

---

## 14. Cost Awareness

The architecture contains AWS services that can generate charges:

- NAT Gateway
- Application Load Balancer
- ECS Fargate
- ECR
- Data transfer

For an actual monthly estimate, use the **AWS Pricing Calculator** based on task count, CPU/memory, ALB usage, NAT traffic, CloudWatch logs, ECR storage and data transfer.

Unused development environments should be destroyed when they are no longer required.

---

## 15. Technologies Used

### Infrastructure

- Terraform
- AWS VPC
- AWS IAM
- Amazon ECS Fargate
- Amazon ECR
- Application Load Balancer
- Amazon S3
- DynamoDB

### CI/CD

- GitHub Actions
- GitHub Environments
- GitHub OIDC

### Containers

- Docker
- Amazon ECR
- ECS Fargate

### Application

- Node.js
- Docker
- Health endpoint
- Automated tests

---

## 16. DevOps Skills Demonstrated

- Infrastructure as Code
- Terraform modules
- AWS networking
- IAM
- Docker
- GitHub Actions
- CI/CD automation
- ECS Fargate
- Amazon ECR
- Application Load Balancer
- GitHub OIDC
- Production approvals
- Health checks
- Automatic rollback
- Container scaling
- Remote Terraform state
- Infrastructure automation

---

### Business problem solved

The project eliminates manual SSH-based production deployments and provides a **repeatable, controlled and auditable deployment process**.

---

## 18. Future Improvements

- Canary deployment
- Blue/green deployment
- Trivy container scanning
- Terraform security scanning
- Prometheus and Grafana
- AWS WAF
- HTTPS with ACM
- Route 53 custom domain
- Multi-account AWS architecture
- Cloudwatch
---

## Project Summary

```text
Terraform
    +
GitHub Actions
    +
Docker
    +
Amazon ECR
    +
ECS Fargate
    +
Application Load Balancer
    +
CloudWatch
    +
Production Approval
    +
Automatic Rollback
    =
Zero-Touch Deployment Platform
```

---

## Author

**Aniket Chatur**

**DevOps | Cloud | Infrastructure Engineering**
